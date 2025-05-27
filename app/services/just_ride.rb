require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class JustrideClient
  BASE_URL  = ENV['JUSTRIDE_BASE_URL']
  USERNAME  = ENV['JUSTRIDE_USERNAME']
  PASSWORD  = ENV['JUSTRIDE_PASSWORD']
  PARTNER   = ENV['JUSTRIDE_PARTNER']
  IDEMP_KEY = -> { SecureRandom.uuid }

  class << self
    ## create shadow account – returns accountId
    def create_external_account(id_token)
      jwe = fetch_jwe_token or return
      post("#{BASE_URL}/external-accounts", jwe, idToken: id_token)['accountId']
    end

    ## add Senior entitlement – returns API json
    def add_senior_entitlement(account_id)
      jwe = fetch_jwe_token or return
      post("#{BASE_URL}/accounts/#{account_id}/entitlements", jwe, senior_body)
    end

    def post(url, auth_header, body_hash)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Authorization']   = auth_header
      req['Jr-Partner']      = PARTNER
      req['Idempotency-Key'] = IDEMP_KEY.call
      req.body               = body_hash.to_json

      Rails.logger.debug "[Justride DEBUG] URL:     #{uri}"
      Rails.logger.debug "[Justride DEBUG] Method:  #{req.method}"
      Rails.logger.debug "[Justride DEBUG] Headers: #{req.to_hash.inspect}"
      Rails.logger.debug "[Justride DEBUG] Body:    #{req.body}"

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.set_debug_output(Rails.logger)  

      res = http.start { |h| h.request(req) }

      Rails.logger.debug "[Justride DEBUG] Response code: #{res.code}"
      Rails.logger.debug "[Justride DEBUG] Response body: #{res.body}"

      JSON.parse(res.body) rescue {}
    end

    ## build Senior entitlement payload (expires 30 years from now)
    def senior_body
      {
        riderTypeRestrictionName: 'Senior',
        proofId:                  'DOB>=65',
        expiresAt:                30.years.from_now.utc.iso8601,
        enabled:                  true
      }
    end

    ## get fresh JWE token
    def fetch_jwe_token
      uri = URI("#{BASE_URL}/auth")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      req.body            = { username: USERNAME, password: PASSWORD }.to_json
      res  = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body)['token'] rescue nil
    end
  end
end
