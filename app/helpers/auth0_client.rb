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
    Rails.logger.info "Successfully fetched JWKS."

    begin
      decoded_token = JWT.decode(token, nil, true, {
        algorithms: ['RS256'],
        jwks: jwks,
        verify_iss: true,
        iss: "https://dev-oaov6y5cfti013hz.us.auth0.com/",
        aud: "https://dev-oaov6y5cfti013hz.us.auth0.com/api/v2/",
        verify_aud: true
      })

      Rails.logger.info "Token decoded successfully: #{decoded_token}"
      OpenStruct.new(decoded_token: decoded_token, error: nil)
    rescue JWT::DecodeError => e
      Rails.logger.error "Token decoding failed: #{e.message}"
      OpenStruct.new(decoded_token: nil, error: OpenStruct.new(message: e.message, status: 401))
    end
  end

  private

  def fetch_jwks
    uri = URI("https://dev-oaov6y5cfti013hz.us.auth0.com/.well-known/jwks.json")
    Rails.logger.info "Fetching JWKS from #{uri}..."
    Net::HTTP.get_response(uri)
  end
end
