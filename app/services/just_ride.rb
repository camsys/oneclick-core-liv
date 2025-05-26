require 'net/http'
require 'uri'
require 'json'
require 'securerandom'

class JustrideClient
  BASE      = 'https://uat.justride.systems/api/v4/RGRTA'
  USERNAME  = 'Here2There_API_Integration'
  PASSWORD  = 'uHWODs{45GNId1S,iEBju'
  PARTNER   = 'here2there'

  def self.create_external_account(id_token)
    jwe = fetch_jwe_token
    return unless jwe

    uri = URI("#{BASE}/external-accounts")
    req = Net::HTTP::Post.new(uri)
    req['Content-Type']    = 'application/json'
    req['Accept']          = 'application/json'
    req['Authorization']   = "Bearer #{jwe}"
    req['Jr-Partner']      = PARTNER
    req['Idempotency-Key'] = SecureRandom.uuid
    req.body               = { idToken: id_token }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    JSON.parse(res.body)['accountId'] rescue nil
  end

  def self.fetch_jwe_token
    uri = URI("#{BASE}/auth")
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req.body            = { username: USERNAME, password: PASSWORD }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    JSON.parse(res.body)['token'] rescue nil
  end
end
