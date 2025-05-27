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

  # minimal Senior entitlement payload
  SENIOR_BODY = {
    riderTypeRestrictionName: 'Senior',
    proofId:                   ENV.fetch('JUSTRIDE_SENIOR_PROOF_ID',   'DOB>=65'),
    expiresAt:                 ENV.fetch('JUSTRIDE_SENIOR_EXPIRES_AT', '2030-12-31T23:59:59Z'),
    enabled:                   true
  }

  class << self
    # create a shadow account & return its accountId
    def create_external_account(id_token)
      jwe = fetch_jwe_token or return
      post("#{BASE_URL}/external-accounts", jwe, { idToken: id_token })['accountId']
    end

    # add the Senior entitlement to an account
    def add_senior_entitlement(account_id)
      jwe = fetch_jwe_token or return
      post("#{BASE_URL}/accounts/#{account_id}/entitlements", jwe, SENIOR_BODY)
    end

    # shared POST helper
    def post(url, auth_header, body_hash)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Authorization']   = auth_header
      req['Jr-Partner']      = PARTNER
      req['Idempotency-Key'] = IDEMP_KEY.call
      req.body               = body_hash.to_json

      Rails.logger.debug "[Justride] POST #{uri.path} -- #{body_hash.inspect}"

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      res = http.start { |h| h.request(req) }

      Rails.logger.debug "[Justride] Response #{res.code}: #{res.body}"
      JSON.parse(res.body) rescue {}
    end

    # fetch a fresh JWE token
    def fetch_jwe_token
      uri = URI("#{BASE_URL}/auth")
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = { username: USERNAME, password: PASSWORD }.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body)['token'] rescue nil
    end
  end
end
