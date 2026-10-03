require "rails_helper"

RSpec.describe "Matchmaking flow", type: :model do
  describe Matchmaking::JoinGame do
    let(:player) { create(:player) }

    context "when no open session exists" do
      it "creates a new waiting session" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result).to have_attributes(matched: false)
        expect(result.session).to have_attributes(
          status:    "waiting",
          player1:   player,
          player2:   nil,
          is_vs_cpu: false,
          game_type: "logic"
        )
      end

      it "generates a matchmaking_token" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result.session.matchmaking_token).to be_present
        expect(result.session.matchmaking_token.length).to be > 10
      end

      it "schedules a CpuFallbackJob" do
        expect {
          described_class.new(player: player, game_type: "logic").call
        }.to have_enqueued_job(Matchmaking::CpuFallbackJob)
      end
    end

    context "when an open waiting session exists for the same game_type" do
      let!(:waiting_session) do
        create(:game_session, game_type: "logic", status: "waiting")
      end

      it "matches into the existing session" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result).to have_attributes(matched: true)
        expect(result.session).to eq(waiting_session)
        expect(result.session).to have_attributes(
          player2: player,
          status:  "active"
        )
      end

      it "does not create a new session" do
        expect {
          described_class.new(player: player, game_type: "logic").call
        }.not_to change(GameSession, :count)
      end

      it "does not enqueue a CpuFallbackJob" do
        expect {
          described_class.new(player: player, game_type: "logic").call
        }.not_to have_enqueued_job(Matchmaking::CpuFallbackJob)
      end
    end

    context "when a waiting session exists but for a different game_type" do
      let!(:waiting_session) do
        create(:game_session, game_type: "strength", status: "waiting")
      end

      it "creates a new session instead of joining the wrong type" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result).to have_attributes(matched: false)
        expect(result.session).not_to eq(waiting_session)
        expect(result.session).to have_attributes(game_type: "logic")
      end
    end

    context "when the player already has an open session" do
      let!(:own_session) do
        create(:game_session, game_type: "logic", status: "waiting", player1: player)
      end

      it "creates a new session instead of matching with itself" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result).to have_attributes(matched: false)
        expect(result.session).not_to eq(own_session)
      end
    end
  end
end
