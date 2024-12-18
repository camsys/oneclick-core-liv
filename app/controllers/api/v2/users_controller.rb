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
        # Extract email via ID token (if provided)
        if params[:id_token].present?
          auth0_client = Auth0Client.new
          validation_response = auth0_client.validate_token(params[:id_token])
      
          if validation_response.error.present?
            Rails.logger.error "Token validation failed: #{validation_response.error}"
            render fail_response(message: "Invalid token", status: 401) and return
          end
      
          decoded_token = validation_response.decoded_token.first
          email = decoded_token["email"]
      
          if email.blank?
            Rails.logger.error "Email missing in decoded token."
            render fail_response(message: "Email is missing in token", status: 401) and return
          end
      
          # Inject email into params for further processing
          params[:user] = { email: email }
        end
      
        # Proceed with the old logic for user session/authentication
        @user = User.find_by(email: user_params[:email].downcase)
        @fail_status = 400
        @errors = {}
      
        if @user.present? && @user.valid_for_api_authentication?(user_params[:password])
          sign_in(:user, @user)
          @user.ensure_authentication_token
          render(success_response(message: "User Signed In Successfully", session: session_hash(@user))) and return
        else
          @errors[:email] = "User not found or invalid credentials"
          render(fail_response(errors: @errors, status: @fail_status))
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