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

    context "when the player already has a valid waiting session" do
      let!(:own_session) do
        create(:game_session, game_type: "logic", status: "waiting", player1: player)
      end

      it "returns it instead of creating or matching with itself (idempotent)" do
        result = nil
        expect { result = described_class.new(player: player, game_type: "logic").call }
          .not_to change(GameSession, :count)

        expect(result).to have_attributes(matched: false)
        expect(result.session).to eq(own_session)
      end

      it "does not enqueue another CpuFallbackJob" do
        expect { described_class.new(player: player, game_type: "logic").call }
          .not_to have_enqueued_job(Matchmaking::CpuFallbackJob)
      end
    end

    context "when the player has expired waiting sessions" do
      let!(:old) do
        create(:game_session, game_type: "logic", status: "waiting", player1: player, expires_at: 1.minute.ago)
      end

      it "expires them and creates a fresh one" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(old.reload.status).to eq("expired")
        expect(result.session).not_to eq(old)
        expect(result.session.status).to eq("waiting")
        expect(GameSession.waiting.where(player1: player).count).to eq(1)
      end
    end

    context "when a waiting session is expired (not yet swept)" do
      let!(:expired) do
        create(:game_session, game_type: "logic", status: "waiting", expires_at: 8.minutes.ago)
      end

      it "never matches into it" do
        result = described_class.new(player: player, game_type: "logic").call

        expect(result.matched).to be(false)
        expect(result.session).not_to eq(expired)
        expect(expired.reload.player2).to be_nil
      end
    end

    context "when several valid waiting sessions exist" do
      let!(:newer) { create(:game_session, game_type: "logic", status: "waiting", created_at: 5.seconds.ago) }
      let!(:older) { create(:game_session, game_type: "logic", status: "waiting", created_at: 20.seconds.ago) }

      it "matches the oldest first" do
        result = described_class.new(player: player, game_type: "logic").call
        expect(result.session).to eq(older)
      end
    end

    context "two sequential players" do
      let(:first)  { create(:player) }
      let(:second) { create(:player) }

      it "matches the second and notifies the first over Action Cable after commit" do
        a = described_class.new(player: first, game_type: "logic").call
        expect(a.matched).to be(false)

        b = nil
        expect { b = described_class.new(player: second, game_type: "logic").call }
          .to have_broadcasted_to("matchmaking_#{a.session.matchmaking_token}")
          .with(hash_including(type: "matched", vs_cpu: false, session_id: a.session.public_id,
                               public_id: a.session.public_id))

        expect(b.matched).to be(true)
        expect(b.session).to eq(a.session)
        expect(b.session.move_deadline_at).to be_within(2.seconds).of(60.seconds.from_now)
      end
    end

    context "simulation isolation" do
      let!(:real_waiting) { create(:game_session, game_type: "logic", status: "waiting") }

      it "does not cross simulated and real pools" do
        result = described_class.new(player: player, game_type: "logic", simulation: true).call
        expect(result.matched).to be(false)
        expect(real_waiting.reload.player2).to be_nil
      end
    end
  end
end
