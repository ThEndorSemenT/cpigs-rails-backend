require "rails_helper"

RSpec.describe MatchmakingChannel, type: :channel do
  let(:player) { create(:player) }
  let(:session) { create(:game_session, game_type: "logic", status: "waiting") }

  describe "#subscribed" do
    it "rejects with an invalid token" do
      subscribe(token: "nonexistent_token")

      expect(subscription).to be_rejected
    end

    it "subscribes with a valid token" do
      subscribe(token: session.matchmaking_token)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("matchmaking_#{session.matchmaking_token}")
    end

    it "transmits matched event immediately if session is already matched" do
      session.update!(status: "active", player2: create(:player), is_vs_cpu: false)

      subscribe(token: session.matchmaking_token)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("matchmaking_#{session.matchmaking_token}")
      expect(transmissions.last).to eq(
        "type" => "matched",
        "vs_cpu" => false,
        "session_id" => session.id
      )
    end

    it "transmits matched event for CPU fallback" do
      session.update!(status: "active", is_vs_cpu: true)

      subscribe(token: session.matchmaking_token)

      expect(transmissions.last).to eq(
        "type" => "matched",
        "vs_cpu" => true,
        "session_id" => session.id
      )
    end
  end

  describe "#unsubscribed" do
    it "stops streaming on unsubscribe" do
      subscribe(token: session.matchmaking_token)

      expect(subscription).to have_stream_from("matchmaking_#{session.matchmaking_token}")

      subscription.unsubscribe_from_channel

      expect(subscription).not_to have_stream_from("matchmaking_#{session.matchmaking_token}")
    end
  end
end
