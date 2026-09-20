FactoryBot.define do
  factory :game_session do
    association :player1, factory: :player
    game_type         { "logic" }
    status            { "waiting" }
    is_vs_cpu         { false }
    matchmaking_token { SecureRandom.urlsafe_base64(16) }
    metadata          { {} }
    expires_at        { 30.seconds.from_now }
  end
end
