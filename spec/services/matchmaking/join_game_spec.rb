require "rails_helper"

RSpec.describe "Matchmaking flow", type: :model do
  describe Matchmaking::JoinGame do
    let(:player) { create(:player) }

    context "when no open session exists" do
      it "creates a new waiting session" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result.matched).to be false
        expect(result.session).to be_a(GameSession)
        expect(result.session.status).to eq("waiting")
        expect(result.session.player1).to eq(player)
        expect(result.session.player2).to be_nil
        expect(result.session.is_vs_cpu).to be false
        expect(result.session.game_type).to eq("logic")
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

        expect(result.matched).to be true
        expect(result.session).to eq(waiting_session)
        expect(result.session.player2).to eq(player)
        expect(result.session.status).to eq("active")
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

        expect(result.matched).to be false
        expect(result.session).not_to eq(waiting_session)
        expect(result.session.game_type).to eq("logic")
      end
    end

    context "when the player already has an open session" do
      let!(:own_session) do
        create(:game_session, game_type: "logic", status: "waiting", player1: player)
      end

      it "creates a new session instead of matching with itself" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result.matched).to be false
        expect(result.session).not_to eq(own_session)
      end
    end
  end
end
