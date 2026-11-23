require "rails_helper"

RSpec.describe "Matchmaking expiry" do
  let(:stream) { ->(s) { "matchmaking_#{s.matchmaking_token}" } }

  describe Matchmaking::ExpireStaleJob do
    let!(:stale)  { create(:game_session, status: "waiting", expires_at: 1.minute.ago) }
    let!(:fresh)  { create(:game_session, status: "waiting", expires_at: 20.seconds.from_now) }
    let!(:overdue) do
      create(:game_session, status: "active", player2: create(:player), move_deadline_at: 5.seconds.ago)
    end

    around { |ex| with_cpu_fallback("false") { ex.run } }

    it "expires stale waiting sessions and broadcasts expired, leaving fresh ones" do
      expect { described_class.perform_now }
        .to have_broadcasted_to(stream.(stale)).with(type: "expired", reason: "timeout")

      expect(stale.reload.status).to eq("expired")
      expect(fresh.reload.status).to eq("waiting")
      expect(overdue.reload.status).to eq("expired")
    end

    it "is idempotent (second run does nothing)" do
      described_class.perform_now
      expect { described_class.perform_now }.not_to have_broadcasted_to(stream.(stale))
    end
  end

  describe "with CPU fallback enabled (default)" do
    let!(:stale) { create(:game_session, status: "waiting", expires_at: 1.second.ago) }

    it "sweeper falls back to CPU once, even when CpuFallbackJob also runs" do
      expect { Matchmaking::ExpireStaleJob.perform_now }
        .to have_broadcasted_to(stream.(stale)).with(hash_including(type: "matched", vs_cpu: true))
      expect(stale.reload).to have_attributes(status: "active", is_vs_cpu: true)
      expect(stale.move_deadline_at).to be_present

      expect { Matchmaking::CpuFallbackJob.perform_now(stale.id); Matchmaking::ExpireStaleJob.perform_now }
        .not_to have_broadcasted_to(stream.(stale))
    end
  end

  describe Matchmaking::CpuFallbackJob do
    it "does nothing when the session is no longer waiting" do
      s = create(:game_session, status: "active", player2: create(:player))
      expect { described_class.perform_now(s.id) }.not_to have_broadcasted_to(stream.(s))
      expect(s.reload.is_vs_cpu).to be(false)
    end

    it "expires instead of CPU fallback when disabled" do
      s = create(:game_session, status: "waiting")
      with_cpu_fallback("false") do
        expect { described_class.perform_now(s.id) }
          .to have_broadcasted_to(stream.(s)).with(type: "expired", reason: "timeout")
      end
      expect(s.reload.status).to eq("expired")
    end
  end

  describe Games::MoveDeadlineJob do
    it "expires an overdue active session, ignores others" do
      late = create(:game_session, status: "playing", player2: create(:player), move_deadline_at: 1.second.ago)
      ok   = create(:game_session, status: "active",  player2: create(:player), move_deadline_at: 30.seconds.from_now)
      done = create(:game_session, status: "resolved", player2: create(:player), move_deadline_at: 1.minute.ago)

      [late, ok, done].each { |s| described_class.perform_now(s.id) }

      expect(late.reload.status).to eq("expired")
      expect(ok.reload.status).to eq("active")
      expect(done.reload.status).to eq("resolved")
    end
  end

  def with_cpu_fallback(value)
    old = ENV["MATCHMAKING_CPU_FALLBACK"]
    ENV["MATCHMAKING_CPU_FALLBACK"] = value
    yield
  ensure
    ENV["MATCHMAKING_CPU_FALLBACK"] = old
  end
end
