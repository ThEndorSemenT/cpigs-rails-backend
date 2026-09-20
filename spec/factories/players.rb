FactoryBot.define do
  factory :player do
    wallet_address { "0x#{SecureRandom.hex(20)}" }
    nonce          { SecureRandom.hex(16) }
  end
end
