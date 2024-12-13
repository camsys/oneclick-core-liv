module Api
  module V1
    class SessionsController < Devise::SessionsController
      # acts_as_token_authentication_handler_for User, fallback: :none
      skip_before_action :verify_signed_out_user
      prepend_before_filter :require_no_authentication, :only => [:create ]
      include Devise::Controllers::Helpers
      include JsonResponseHelper::ApiErrorCatcher # Catches 500 errors and sends back JSON with headers.

      # clear_respond_to
      respond_to :json

      # Custom sign_in method renders JSON rather than HTML
      def create
        Rails.logger.info "Received params: #{params.inspect}"
      
        # Check for the presence of an Auth0 ID Token
        id_token = params[:id_token]
        if id_token.present?
          Rails.logger.info "Auth0 login flow detected. ID Token provided: #{id_token}"
      
          # Validate and decode the ID Token
          auth0_client = Auth0Client.new
          Rails.logger.info "Validating ID Token..."
          validation_response = auth0_client.validate_token(id_token)
          
          if validation_response.error
            Rails.logger.error "Auth0 Token validation failed: #{validation_response.error.message}"
            render status: 401, json: { message: validation_response.error.message }
            return
          end
          
          decoded_token = validation_response.decoded_token.first
          Rails.logger.info "ID Token successfully validated. Decoded token: #{decoded_token.inspect}"
      
          # Extract the user's email from the token
          email = decoded_token['email']
          if email.blank?
            Rails.logger.error "Decoded token is invalid. Email is missing."
            render status: 401, json: { message: 'Invalid token: email is missing.' }
            return
          end
          Rails.logger.info "Extracted email from ID Token: #{email}"
      
          # Find or create the user in the database
          @user = User.find_or_create_by(email: email) do |user|
            user.first_name = decoded_token['given_name']
            user.last_name = decoded_token['family_name']
            user.password = SecureRandom.hex(10) # Random password since Auth0 manages authentication
            Rails.logger.info "Creating a new user with email: #{email}"
          end
          Rails.logger.info "User found or created: #{@user.inspect}"
      
          # Sign in the user and issue the authentication token
          Rails.logger.info "Signing in the user..."
          sign_in(:user, @user)
          Rails.logger.info "User signed in. Ensuring authentication token is set..."
          @user.ensure_authentication_token
          Rails.logger.info "Authentication token generated: #{@user.authentication_token}"
      
          render status: 200, json: {
            authentication_token: @user.authentication_token,
            email: @user.email,
            first_name: @user.first_name,
            last_name: @user.last_name
          }
          return
        end
        
        # Fallback for legacy login using email and password
        Rails.logger.info "Legacy login flow detected. No ID Token provided."
        email = session_params[:email].try(:downcase)
        password = session_params[:password]
        Rails.logger.info "Extracted email: #{email}, checking credentials..."
        @user = User.find_by(email: email)
      
        if @user && @user.valid_password?(password)
          Rails.logger.info "Valid credentials provided. Signing in the user..."
          sign_in(:user, @user)
          Rails.logger.info "User signed in successfully. Generating authentication token..."
          @user.ensure_authentication_token
          Rails.logger.info "Authentication token generated: #{@user.authentication_token}"
      
          render status: 200, json: {
            authentication_token: @user.authentication_token,
            email: @user.email
          }
        else
          Rails.logger.error "Invalid credentials provided for email: #{email}"
          render status: 401, json: { message: "Invalid email or password." }
        end
      end          

      # Custom sign_out method renders JSON and handles invalid token errors.
      def destroy
        user_token = request.headers["X-User-Token"] || params[:user_token] || params[:session][:user_token]
        @user = User.find_by(authentication_token: user_token) if user_token

        if @user
          @user.update_attributes(authentication_token: nil)
          sign_out(@user)
          render status: 200, json: { message: 'User successfully signed out.'}
        else
          render status: 401,
            json: json_response(:fail, data: {user: 'Please provide a valid token.' })
        end
      end

      private

      def session_params
        params[:session] = params.delete :user if params.has_key? :user
        params.require(:session).permit(:email, :password, :ecolane_id, :county, :dob, :service_id)
      end

    end
  end
end
