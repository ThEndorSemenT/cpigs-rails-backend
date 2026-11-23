require "rails_helper"

# The client controls the mode, so isolation between real and simulated play is the
# main defence: `sim` tokens carry no wallet proof and must never reach real data.
RSpec.describe "Simulation isolation", type: :request do
  let(:wallet)     { "0x#{'ab' * 20}" }
  let!(:player)    { create(:player, wallet_address: wallet) }
  let(:real_token) { TokenService.encode(wallet) }
  let(:sim_token)  { TokenService.encode(wallet, sim: true) }

  def auth(token, extra = {}) = { "Authorization" => "Bearer #{token}" }.merge(extra)

  describe "matchmaking" do
    it "creates a simulated session for a simulated request" do
      post "/api/v1/matchmaking", params: { game_type: "logic" }, headers: auth(sim_token, sim_headers)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["simulation"]).to be(true)
      expect(GameSession.last.simulation).to be(true)
    end

    it "creates a real session without the header" do
      post "/api/v1/matchmaking", params: { game_type: "logic" }, headers: auth(real_token)
      expect(JSON.parse(response.body)["simulation"]).to be(false)
      expect(GameSession.last.simulation).to be(false)
    end

    it "rejects a sim token on a real (header-less) request with 401" do
      post "/api/v1/matchmaking", params: { game_type: "logic" }, headers: auth(sim_token)
      expect(response).to have_http_status(:unauthorized)
      expect(GameSession.count).to eq(0)
    end

    it "is an explicit 403 when simulation is requested but not allowed", :simulation_not_allowed do
      post "/api/v1/matchmaking", params: { game_type: "logic" }, headers: auth(real_token, sim_headers)
      expect(response).to have_http_status(:forbidden)
      expect(GameSession.count).to eq(0)
    end

    it "never pairs a simulated player with a real one (either direction)" do
      real_p = create(:player)
      sim_p  = create(:player)
      real_s = GameSession.find_or_create_for_matchmaking(player: real_p, game_type: "logic")
      sim_s  = GameSession.find_or_create_for_matchmaking(player: sim_p, game_type: "logic", simulation: true)
      expect(sim_s).not_to eq(real_s)
      expect(real_s.reload.player2).to be_nil

      other_sim = GameSession.find_or_create_for_matchmaking(player: create(:player), game_type: "logic", simulation: true)
      expect(other_sim).to eq(sim_s)
      other_real = GameSession.find_or_create_for_matchmaking(player: create(:player), game_type: "logic")
      expect(other_real).to eq(real_s)
    end
  end

  describe "game session access" do
    let(:real_session) { create(:game_session, player1: player) }
    let(:sim_session)  { create(:game_session, player1: player, simulation: true) }

    it "hides real sessions from simulated requests and vice versa" do
      get "/api/v1/game_sessions/#{real_session.to_param}", headers: auth(sim_token, sim_headers)
      expect(response).to have_http_status(:not_found)

      get "/api/v1/game_sessions/#{sim_session.to_param}", headers: auth(real_token)
      expect(response).to have_http_status(:not_found)
    end

    it "rejects a sim token on a real session (header-less) and on submit_move" do
      get "/api/v1/game_sessions/#{real_session.to_param}", headers: auth(sim_token)
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/game_sessions/#{real_session.to_param}/moves",
           params: { move_type: "guess_card", payload: { index: 0 } }, headers: auth(sim_token)
      expect(response).to have_http_status(:unauthorized)
      expect(Move.count).to eq(0)
    end

    it "even a sim token + header cannot submit a move to a real session" do
      post "/api/v1/game_sessions/#{real_session.to_param}/moves",
           params: { move_type: "guess_card", payload: { index: 0 } }, headers: auth(sim_token, sim_headers)
      expect(response).to have_http_status(:not_found)
      expect(Move.count).to eq(0)
    end

    it "serves a simulated session to a simulated request" do
      get "/api/v1/game_sessions/#{sim_session.to_param}", headers: auth(sim_token, sim_headers)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["simulation"]).to be(true)
    end
  end
end
