require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class JustrideClient
  BASE_URL   = ENV.fetch('JUSTRIDE_BASE_URL')
  USERNAME   = ENV.fetch('JUSTRIDE_USERNAME')
  PASSWORD   = ENV.fetch('JUSTRIDE_PASSWORD')
  PARTNER    = ENV.fetch('JUSTRIDE_PARTNER')
  IDEMP_KEY  = -> { SecureRandom.uuid }
  SENIOR_BODY = { riderTypeRestrictionName: 'Senior', enabled: true }.freeze

  class << self
    # Creates a shadow Justride account and returns the accountId
    def create_external_account(id_token)
      jwe = fetch_jwe_token
      return unless jwe
      res = post("#{BASE_URL}/external-accounts", jwe, idToken: id_token)
      res['accountId']
    end

    # Adds a senior entitlement to an existing Justride account
    def add_senior_entitlement(account_id)
      jwe = fetch_jwe_token
      return unless jwe
      post("#{BASE_URL}/accounts/#{account_id}/entitlements", jwe, SENIOR_BODY)
    end

    # Sends a POST request with authorization and idempotency headers
    def post(url, auth_header, body_hash)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Authorization']   = auth_header
      req['Jr-Partner']      = PARTNER
      req['Idempotency-Key'] = IDEMP_KEY.call
      req.body               = body_hash.to_json

      Rails.logger.info("[Justride] POST #{uri.path} #{body_hash}")
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body) rescue {}
    end

    # Fetches a fresh JWE token for Justride API requests
    def fetch_jwe_token
      uri = URI("#{BASE_URL}/auth")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      req.body = { username: USERNAME, password: PASSWORD }.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body)['token'] rescue nil
    end
  end
end
