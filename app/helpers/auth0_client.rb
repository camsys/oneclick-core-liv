require 'jwt'
require 'net/http'

class Auth0Client
  def validate_token(token)
    Rails.logger.info "Starting token validation..."

    # Fetch the JWKS from the Auth0 endpoint
    jwks_response = fetch_jwks

    unless jwks_response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Failed to fetch JWKS: #{jwks_response.code} #{jwks_response.message}"
      return OpenStruct.new(decoded_token: nil, error: OpenStruct.new(message: 'Unable to fetch JWKS', status: 500))
    end

    # Parse the JWKS
    jwks = JSON.parse(jwks_response.body, symbolize_names: true)
    Rails.logger.info "DEBUG: JWKS fetched successfully."

    # Attempt to decode the token
    begin
      decoded_token = JWT.decode(token, nil, true, {
        algorithms: ['RS256'],
        jwks: { keys: jwks[:keys] },
        verify_iss: true,
        iss: "https://dev-oaov6y5cfti013hz.us.auth0.com/",
        aud: "EnsRsHiDdxAAQEAJ6hnXEGl8GPGdSgFW",
        verify_aud: true
      })

      Rails.logger.info "DEBUG: Successfully decoded token: #{decoded_token.inspect}"
      OpenStruct.new(decoded_token: decoded_token, error: nil)
    rescue JWT::DecodeError => e
      Rails.logger.error "Token decoding failed: #{e.message}"
      OpenStruct.new(decoded_token: nil, error: OpenStruct.new(message: 'Invalid token', status: 401))
    end
  end

  private

  def fetch_jwks
    uri = URI("https://dev-oaov6y5cfti013hz.us.auth0.com/.well-known/jwks.json")
    Rails.logger.info "Fetching JWKS from #{uri}..."
    Net::HTTP.get_response(uri)
  end
end