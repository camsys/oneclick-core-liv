# app/lib/justride_client.rb
class JustrideClient
  BASE_URL   = ENV.fetch('JUSTRIDE_BASE_URL')
  USERNAME   = ENV.fetch('JUSTRIDE_USERNAME')
  PASSWORD   = ENV.fetch('JUSTRIDE_PASSWORD')
  PARTNER    = ENV.fetch('JUSTRIDE_PARTNER')
  IDEMP_KEY  = -> { SecureRandom.uuid }
  ENTITLEMENT_EXPIRY = '2125-12-31T23:59:59Z'

  SENIOR_BODY = {
    riderTypeRestrictionName: 'Senior',
    proofId:   'DOB>=60',
    expiresAt: ENTITLEMENT_EXPIRY,
    enabled:   true
  }

  class << self
    ## create shadow account – returns accountId (or nil)
    def create_external_account(id_token)
      jwe = fetch_jwe_token or return
      resp = post("#{BASE_URL}/external-accounts", jwe, { idToken: id_token })
      resp['accountId']
    end

    ## add Senior entitlement
    def add_senior_entitlement(account_id)
      jwe = fetch_jwe_token or return
      post("#{BASE_URL}/accounts/#{account_id}/entitlements", jwe, SENIOR_BODY)
    end

    private

    def post(url, auth, body)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']    = 'application/json'
      req['Authorization']   = auth
      req['Jr-Partner']      = PARTNER
      req['Idempotency-Key'] = IDEMP_KEY.call
      req.body               = body.to_json

      dump('URL',     uri.to_s)
      dump('Headers', req.to_hash)
      dump('Body',    body)

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
      dump('Response', "#{res.code} #{res.message}")
      dump('Resp-body', res.body)

      JSON.parse(res.body) rescue {}
    end

    def fetch_jwe_token
      uri = URI("#{BASE_URL}/auth")
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = { username: USERNAME, password: PASSWORD }.to_json
      res      = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
      JSON.parse(res.body)['token'] rescue nil
    end

    def dump(label, value)
      Rails.logger.debug("[Justride DEBUG] #{label}: #{value.inspect}")
    end
  end
end
