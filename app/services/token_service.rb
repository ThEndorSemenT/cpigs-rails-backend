# Stateless HMAC-signed token for wallet authentication.
# Token payload: { "wallet" => "0x...", "exp" => unix_timestamp }
class TokenService
  ALGORITHM = "HS256"

  class << self
    def encode(wallet_address, exp: 24.hours.from_now)
      payload = { wallet: wallet_address.downcase, exp: exp.to_i }
      data = Base64.urlsafe_encode64(payload.to_json, padding: false)
      sig = OpenSSL::HMAC.hexdigest("SHA256", secret, data)
      "#{data}.#{sig}"
    end

    def decode(token)
      data, sig = token.to_s.split(".", 2)
      return nil if data.blank? || sig.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, data)
      return nil unless ActiveSupport::SecurityUtils.secure_compare(sig, expected)

      payload = JSON.parse(Base64.urlsafe_decode64(data))
      return nil if Time.at(payload["exp"]) < Time.current

      payload
    rescue ArgumentError, JSON::ParserError
      nil
    end

    private

    def secret
      Rails.application.secret_key_base
    end
  end
end
