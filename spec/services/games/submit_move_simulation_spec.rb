require "rails_helper"

RSpec.describe Games::SubmitMove do
  before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

  let(:p1)      { create(:player) }
  let(:p2)      { create(:player) }
  let(:session) { create(:game_session, player1: p1, player2: p2, status: "active") }

  def cards_for(player, powers)
    powers.each_with_index.map do |bp, i|
      nft = create(:simulated_nft, wallet_address: player.wallet_address, token_id: "#{player.id}-#{i}", burn_power: bp)
      { "token_id" => nft.token_id, "burn_power" => nft.burn_power }
    end
  end

  def submit(player, type, payload)
    described_class.new(session: session, player: player, move_type: type, payload: payload).call
  end

  context "simulation mode", :simulation do
    it "rejects cards the wallet does not own" do
      foreign = cards_for(p2, [1, 2, 3])
      expect(submit(p1, "select_cards", { "cards" => foreign }).error).to match(/Invalid move payload/)
    end

    it "rejects tampered burn_power and duplicate cards" do
      mine = cards_for(p1, [1, 2, 3])
      tampered = mine.map(&:dup).tap { |c| c[0]["burn_power"] = 99 }
      expect(submit(p1, "select_cards", { "cards" => tampered }).error).to be_present
      expect(submit(p1, "select_cards", { "cards" => [mine[0]] * 3 }).error).to be_present
    end

    it "rejects non-available cards" do
      mine = cards_for(p1, [1, 2, 3])
      SimulatedNft.where(token_id: mine[0]["token_id"]).update_all(status: "lost")
      expect(submit(p1, "select_cards", { "cards" => mine }).error).to be_present
    end

    it "resolves inline and returns the result without enqueuing the resolve job" do
      c1 = cards_for(p1, [1, 2, 10])
      c2 = cards_for(p2, [3, 4, 5])
      expect(submit(p1, "select_cards", { "cards" => c1 }).error).to be_nil
      expect(submit(p2, "select_cards", { "cards" => c2 }).error).to be_nil
      submit(p1, "guess_card", { "index" => 2 }) # p1 guesses p2's 5
      res = submit(p2, "guess_card", { "index" => 0 }) # p2 guesses p1's 1

      expect(res.resolution_triggered).to be(true)
      expect(res.game_result.winner).to eq(p1)
      expect(session.reload.status).to eq("resolved")
      expect(Games::ResolveSessionJob).not_to have_been_enqueued
    end
  end

  context "real mode (regression)" do
    it "does not check ownership and defers resolution to the job" do
      c1 = [{ "token_id" => "a", "burn_power" => 1 }, { "token_id" => "b", "burn_power" => 2 }, { "token_id" => "c", "burn_power" => 3 }]
      expect(submit(p1, "select_cards", { "cards" => c1 }).error).to be_nil
      submit(p2, "select_cards", { "cards" => c1 })
      submit(p1, "guess_card", { "index" => 0 })
      res = submit(p2, "guess_card", { "index" => 0 })

      expect(res.resolution_triggered).to be(true)
      expect(res.game_result).to be_nil
      expect(session.reload.status).to eq("resolving")
      expect(Games::ResolveSessionJob).to have_been_enqueued.with(session.id)
    end
  end
end
