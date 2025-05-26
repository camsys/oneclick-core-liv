require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class JustrideClient
  BASE_URL  = 'https://uat.justride.systems/api/v4/RGRTA'
  USERNAME  = 'Here2There_API_Integration'
  PASSWORD  = 'uHWODs{45GNId1S,iEBju'
  IDEMP_KEY = -> { SecureRandom.uuid }
  SENIOR_BODY = { riderTypeRestrictionName: 'Senior', enabled: true }

  class << self
    ## create shadow account – returns accountId or nil
    def create_external_account(id_token)
      jwe = fetch_jwe_token
      return unless jwe
      res = post("#{BASE_URL}/external-accounts", jwe, idToken: id_token)
      res['accountId']
    end

    ## attach Senior entitlement to an account – returns API json / nil
    def add_senior_entitlement(account_id)
      jwe = fetch_jwe_token
      return unless jwe
      post("#{BASE_URL}/accounts/#{account_id}/entitlements", jwe, SENIOR_BODY)
    end

    ## shared POST helper
    def post(url, auth, body)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Idempotency-Key'] = IDEMP_KEY.call
      req['Authorization']   = auth
      req.body               = body.to_json
      Rails.logger.info("[Justride] POST #{uri.path} #{body}")
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body) rescue {}
    end

    ## fetch + return fresh JWE token
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
