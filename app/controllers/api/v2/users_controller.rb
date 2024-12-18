module Api
  module V2
    class UsersController < ApiController
      include Devise::Controllers::SignInOut

      # before_action :require_authentication, except: [:create, :new_session, :reset_password]
      before_action :require_authentication, only: [:end_session, :destroy]
      before_action :attempt_authentication, only: [:show, :update]

      # Get the user profile 
      def show
        if @traveler.present?
          render(success_response(@traveler))
        else
          render(fail_response(status: 404, message: "Not found"))
        end
      end

      # Update's the user's profile
      def update

        unless @traveler.present?
          render(fail_response(status: 404, message: "Not found"))
        end
        
        # user.update_profile call filters out any unsafe params
        begin 
          if @traveler.update_profile(params)
            set_locale # based on traveler's new preferred locale
            render(success_response(@traveler))
          else
            render(fail_response(status: 400, message: "Unable to update."))
          end
        rescue => exception 
          render(fail_response(status: 400, message: "Unable to update."))
        end
      end
      
      # Sign up a new user
      # POST /sign_up
      # POST /users
      def create
        @user = User.new(user_params)
        
        if @user.save
          sign_in(:user, @user)
          @user.ensure_authentication_token
          # UserMailer.new_traveler(@user).deliver_now
          render(success_response(message: "User Signed Up Successfully", session: session_hash(@user)))
        else
          render(fail_response(errors: @user.errors.to_h))
        end
      end
      
      # Signs in an existing user, returning auth token
      # POST /sign_in
      # Leverages devise lockable module: https://github.com/plataformatec/devise/blob/master/lib/devise/models/lockable.rb
      def new_session
        Rails.logger.info "Received params: #{params.inspect}"
      
        id_token = params[:id_token]
        if id_token.blank?
          Rails.logger.error "ID Token is missing in the request."
          render fail_response(message: "ID Token is required", status: 400)
          return
        end
      
        Rails.logger.info "ID Token provided: #{id_token}"
      
        auth0_client = Auth0Client.new
        validation_response = auth0_client.validate_token(id_token)
      
        Rails.logger.info "Validation response: #{validation_response.inspect}"
      
        decoded_token = validation_response.decoded_token.first
        Rails.logger.info "Token validated successfully. Decoded token: #{decoded_token.inspect}"
      
        email = decoded_token['email']
        if email.blank?
          Rails.logger.error "Decoded token is missing email."
          render fail_response(message: "Invalid token: email is missing", status: 401)
          return
        end
      
        Rails.logger.info "Email extracted from token: #{email}"
      
        @user = User.find_by(email: email)

        Rails.logger.info "User found: #{@user}"
      
        if @user.persisted?
          Rails.logger.info "User found or created successfully. Signing in user..."
          sign_in(:user, @user)
          @user.ensure_authentication_token
      
          render success_response(
            message: "User signed in successfully",
            session: session_hash(@user)
          )
        else
          Rails.logger.error "Failed to find or create user."
          render fail_response(message: "Failed to sign in the user", status: 400)
        end
      end          
          
      
      # Resets the user's password to a random string and sends it to them via email
      # POST /reset_password
      def reset_password
        email = user_params[:email].downcase 
        @user = User.find_by(email: email)
        
        # Send a failure response if no account exists with the given email
        unless @user.present?
          render(fail_response(message: "User #{email} does not exist")) and return
        end
      
        @user.send_api_v2_reset_password_instructions
        
        render(success_response(message: "Password reset email sent to #{email}."))
        
      end

      # Resets the user's password to a random string and sends it to them via email
      # POST /reset_password
      def resend_email_confirmation
        email = user_params[:email].downcase 
        @user = User.find_by(email: email)

        # Send a failure response if no account exists with the given email
        unless @user.present?
          render(fail_response(message: "User #{email} does not exist")) and return
        end

        @user.send_api_v2_email_confirmation_instructions

        render(success_response(message: "Email confirmation sent to#{email}."))

      end
      
      
      # Signs out a user based on email and auth token headers
      # DELETE /sign_out
      def end_session
        
        if @traveler && @traveler.reset_authentication_token
          sign_out(@user)
          render(success_response(message: "User #{@traveler.email} successfully signed out."))
        else
          render(fail_response)
        end
        
      end

      # Placeholder for possible future destroy user call
      def destroy
        puts params.ai
      end
      
      
      # Subscribe user to email updates by email (no token required)
      # POST api/v2/users/subscribe
      def subscribe
        @traveler = User.find_by(email: auth_headers[:email])
        if(@traveler && @traveler.update_attributes(subscribed_to_emails: true))
          render(success_response(message: "User #{@traveler.email} subscribed to email updates."))
        else
          render(fail_response)
        end
      end
      
      # Unsubscribe user from email updated by email (no token required)
      # POST api/v2/users/unsubscribe
      def unsubscribe        
        @traveler = User.find_by(email: auth_headers[:email])
        if(@traveler && @traveler.update_attributes(subscribed_to_emails: false))
          render(success_response(message: "User #{@traveler.email} unsubscribed from email updates."))
        else
          render(fail_response)
        end
      end

      def counties
        counties = County.all.map { |county| { name: county.name } }
        render({
          status: 200,
          json: {
            status: "success",
            data: counties
          }
        })
      end
      
      private
      
      # Returns the signed in user's email and authentication token
      def session_hash(user)
        {
          email: user.email,
          authentication_token: user.authentication_token
        }
      end
      
      def user_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation,
          :first_name,
          :last_name,
          :age,
          :county,
          :paratransit_id          
        )
      end

    end
  end
end