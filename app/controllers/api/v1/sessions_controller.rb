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
        # Extract and decode the Auth0 ID Token from params
        id_token = params[:id_token]
        if id_token.blank?
          render status: 400, json: { message: 'ID Token is required.' }
          return
        end
      
        # Validate and decode the ID Token using Auth0's public keys
        auth0_client = Auth0Client.new
        validation_response = auth0_client.validate_token(id_token)
      
        if validation_response.error
          render status: 401, json: { message: validation_response.error.message }
          return
        end
      
        decoded_token = validation_response.decoded_token.first
      
        # Extract the user's email from the token
        email = decoded_token['email']
        if email.blank?
          render status: 401, json: { message: 'Invalid token: email is missing.' }
          return
        end
      
        # Find or create the user in the database
        @user = User.find_or_create_by(email: email) do |user|
          user.first_name = decoded_token['given_name']
          user.last_name = decoded_token['family_name']
          user.password = SecureRandom.hex(10) # Random password since Auth0 manages authentication
        end
      
        # Sign in the user and issue the authentication token
        sign_in(:user, @user)
        @user.ensure_authentication_token
      
        render status: 200, json: {
          authentication_token: @user.authentication_token,
          email: @user.email,
          first_name: @user.first_name,
          last_name: @user.last_name
        }
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
