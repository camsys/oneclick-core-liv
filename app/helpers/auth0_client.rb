require 'jwt'
require 'net/http'

class Auth0Client
  def validate_token(token)
    jwks_response = fetch_jwks

    unless jwks_response.is_a?(Net::HTTPSuccess)
      return OpenStruct.new(decoded_token: nil, error: OpenStruct.new(message: 'Unable to fetch JWKS', status: 500))
    end

    jwks = JSON.parse(jwks_response.body, symbolize_names: true)
    decoded_token = JWT.decode(token, nil, true, {
      algorithms: ['RS256'],
      jwks: jwks,
      verify_iss: true,
      iss: "https://#{Rails.configuration.auth0['domain']}/",
      aud: Rails.configuration.auth0['audience'],
      verify_aud: true
    })

    OpenStruct.new(decoded_token: decoded_token, error: nil)
  rescue JWT::DecodeError => e
    OpenStruct.new(decoded_token: nil, error: OpenStruct.new(message: e.message, status: 401))
  end

  private

  def fetch_jwks
    uri = URI("https://#{Rails.configuration.auth0['domain']}/.well-known/jwks.json")
    Net::HTTP.get_response(uri)
  end
end
