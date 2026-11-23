require "rails_helper"

RSpec.describe Blockchain::NotifyResultJob do
  let(:simulated) { false }
  let(:session) { create(:game_session, simulation: simulated) }
  let!(:game_result) { GameResult.create!(game_session: session, winner: session.player1, blockchain_status: "pending") }

  before do
    allow(Faraday).to receive(:new).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
  end

  context "simulated session" do
    let(:simulated) { true }

    it "skips the blockchain and never builds a Faraday connection" do
      described_class.perform_now(game_result.id)
      expect(game_result.reload.blockchain_status).to eq("skipped")
      expect(Faraday).not_to have_received(:new)
    end

    it "skips even if the environment no longer allows simulation (session is the source of truth)", :simulation_not_allowed do
      described_class.perform_now(game_result.id)
      expect(game_result.reload.blockchain_status).to eq("skipped")
      expect(Faraday).not_to have_received(:new)
    end
  end

  context "real mode (regression)" do
    it "posts to the result API and marks notified" do
      allow(Rails.application).to receive(:config_for).with(:settings)
        .and_return({ "game" => { "result_api_url" => "https://api.test/result", "result_api_key" => "k" } })
      conn = instance_double(Faraday::Connection)
      allow(conn).to receive(:post).and_return(instance_double(Faraday::Response, body: "ok", status: 200))
      allow(Faraday).to receive(:new).and_return(conn)

      described_class.perform_now(game_result.id)
      expect(conn).to have_received(:post).with("https://api.test/result", hash_including(apiKey: "k"))
      expect(game_result.reload.blockchain_status).to eq("notified")
    end

    it "still skips when URL/key are missing" do
      allow(Rails.application).to receive(:config_for).with(:settings).and_return({})
      allow(ENV).to receive(:fetch).with("GAME_RESULT_API_URL", nil).and_return(nil)
      described_class.perform_now(game_result.id)
      expect(game_result.reload.blockchain_status).to eq("skipped")
    end
  end
end
