FactoryBot.define do
  factory :simulated_nft do
    wallet_address { "0x#{SecureRandom.hex(20)}" }
    collection     { "cpigs-collection-879234287" }
    sequence(:token_id) { |n| (1000 + n).to_s }
    name           { "Test Pig" }
    image_url      { "/img.png" }
    burn_power     { 5 }
    status         { "available" }
  end
end
