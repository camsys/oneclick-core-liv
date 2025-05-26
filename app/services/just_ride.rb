require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class JustrideClient
  BASE      = 'https://uat.justride.systems/api/v4/RGRTA'
  USERNAME  = 'Here2There_API_Integration'
  PASSWORD  = 'uHWODs{45GNId1S,iEBju'
  PARTNER   = 'here2there'

  class << self
    def create_external_account(id_token)
      Rails.logger.info "[Justride] starting external-accounts call…"

      jwe = fetch_jwe_token
      unless jwe
        Rails.logger.error "[Justride] could not obtain JWE auth token – aborting."
        return nil
      end

      uri = URI("#{BASE}/external-accounts")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Accept']          = 'application/json'
      req['Authorization']   = "JWE #{jwe}"
      req['Jr-Partner']      = PARTNER
      req['Idempotency-Key'] = SecureRandom.uuid
      req.body               = { idToken: id_token }.to_json

      Rails.logger.info "[Justride] POST #{uri}"
      Rails.logger.info "[Justride] Headers: #{req.to_hash}"
      Rails.logger.info "[Justride] Body   : #{req.body}"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }

      Rails.logger.info "[Justride] Response code: #{res.code}"
      Rails.logger.info "[Justride] Response body: #{res.body}"

      begin
        account_id = JSON.parse(res.body)['accountId']
        Rails.logger.info "[Justride] Parsed accountId: #{account_id}"
        account_id
      rescue JSON::ParserError => e
        Rails.logger.error "[Justride] JSON parse failed: #{e.message}"
        nil
      end
    end

    def fetch_jwe_token
      uri = URI("#{BASE}/auth")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      req.body            = { username: USERNAME, password: PASSWORD }.to_json

      Rails.logger.info "[Justride] POST #{uri} for JWE"
      Rails.logger.info "[Justride] Body: #{req.body}"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }

      Rails.logger.info "[Justride] JWE response code: #{res.code}"
      Rails.logger.info "[Justride] JWE response body: #{res.body}"

      begin
        token = JSON.parse(res.body)['token']
        Rails.logger.info "[Justride] Extracted JWE token length: #{token&.length}"
        token
      rescue JSON::ParserError => e
        Rails.logger.error "[Justride] JWE JSON parse failed: #{e.message}"
        nil
      end
    end
  end
end
