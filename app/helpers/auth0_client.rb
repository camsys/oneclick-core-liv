require 'jwt'
require 'net/http'

class Auth0Client
  def validate_token(token)
    Rails.logger.info "Starting token validation..."

    jwks_response = fetch_jwks

    unless jwks_response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Failed to fetch JWKS: #{jwks_response.code} #{jwks_response.message}"
      return OpenStruct.new(decoded_token: nil, error: OpenStruct.new(message: 'Unable to fetch JWKS', status: 500))
    end

    jwks = JSON.parse(jwks_response.body, symbolize_names: true)
    Rails.logger.info "DEBUG: Received ID Token: #{token}"
    Rails.logger.info "DEBUG: Decoding token with expected audience: https://dev-oaov6y5cfti013hz.us.auth0.com/api/v2/"
    Rails.logger.info "DEBUG: JWKS fetched: #{jwks.inspect}"
    
    begin
      decoded_token = JWT.decode(token, nil, true, {
        algorithms: ['RS256'],
        jwks: jwks,
        verify_iss: true,
        iss: "https://dev-oaov6y5cfti013hz.us.auth0.com/",
        aud: "https://dev-oaov6y5cfti013hz.us.auth0.com/api/v2/",
        verify_aud: true
      })
    
      Rails.logger.info "DEBUG: Successfully decoded token: #{decoded_token.inspect}"
    rescue JWT::DecodeError => e
      Rails.logger.error "DEBUG: Token decoding failed: #{e.message}"
    end
    
  end

  private

  def fetch_jwks
    uri = URI("https://dev-oaov6y5cfti013hz.us.auth0.com/.well-known/jwks.json")
    Rails.logger.info "Fetching JWKS from #{uri}..."
    Net::HTTP.get_response(uri)
  end
end
