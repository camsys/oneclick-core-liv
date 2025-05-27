require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class JustrideClient
  BASE_URL   = ENV['JUSTRIDE_BASE_URL']
  USERNAME   = ENV['JUSTRIDE_USERNAME']
  PASSWORD   = ENV['JUSTRIDE_PASSWORD']
  PARTNER    = ENV['JUSTRIDE_PARTNER']
  IDEMP_KEY  = -> { SecureRandom.uuid }
  SENIOR_BODY = { riderTypeRestrictionName: 'Senior', enabled: true }

  class << self
    ## create shadow account – returns accountId
    def create_external_account(id_token)
      jwe = fetch_jwe_token or return
      post("#{BASE_URL}/external-accounts", jwe, idToken: id_token)['accountId']
    end

    ## add Senior entitlement – returns API json
    def add_senior_entitlement(account_id)
      jwe = fetch_jwe_token or return
      post("#{BASE_URL}/accounts/#{account_id}/entitlements", jwe, SENIOR_BODY)
    end

    ## generic POST helper
    def post(url, auth, body)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Authorization']   = auth
      req['Jr-Partner']      = PARTNER
      req['Idempotency-Key'] = IDEMP_KEY.call
      req.body               = body.to_json
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body) rescue {}
    end

    ## get fresh JWE token
    def fetch_jwe_token
      uri = URI("#{BASE_URL}/auth")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      req.body            = { username: USERNAME, password: PASSWORD }.to_json
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body)['token'] rescue nil
    end
  end
end
