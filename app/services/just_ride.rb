require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class JustrideClient
  BASE_URL  = 'https://uat.justride.systems/api/v4/RGRTA'
  USERNAME  = 'Here2There_API_Integration'
  PASSWORD  = 'uHWODs{45GNId1S,iEBju'
  IDEMP_KEY = -> { SecureRandom.uuid }

  class << self
    def create_external_account(id_token)
      Rails.logger.info('[Justride] starting external-accounts call…')
      jwe = fetch_jwe_token
      return unless jwe

      uri = URI("#{BASE_URL}/external-accounts")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Idempotency-Key'] = IDEMP_KEY.call
      req['Authorization']   = jwe
      req.body               = { idToken: id_token }.to_json

      Rails.logger.info("[Justride] POST #{uri}")
      Rails.logger.debug("[Justride] Headers: #{req.each_header.to_h}")
      Rails.logger.debug("[Justride] Body   : #{req.body}")

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      Rails.logger.info("[Justride] Response code: #{response.code}")
      Rails.logger.info("[Justride] Response body: #{response.body}")

      parsed      = JSON.parse(response.body) rescue {}
      account_id  = parsed['accountId']
      Rails.logger.info("[Justride] Parsed accountId: #{account_id.inspect}")
      account_id
    end

    private

    def fetch_jwe_token
      uri = URI("#{BASE_URL}/auth")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      req.body            = { username: USERNAME, password: PASSWORD }.to_json

      Rails.logger.info("[Justride] POST #{uri} for JWE")
      Rails.logger.debug("[Justride] Body: #{req.body}")

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      Rails.logger.info("[Justride] JWE response code: #{response.code}")
      Rails.logger.info("[Justride] JWE response body: #{response.body}")

      parsed = JSON.parse(response.body) rescue {}
      token  = parsed['token']
      Rails.logger.info("[Justride] Extracted JWE token length: #{token.to_s.length}")
      token
    end
  end
end
