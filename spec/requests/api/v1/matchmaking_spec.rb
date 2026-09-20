require "rails_helper"

RSpec.describe "Api::V1::Matchmaking", type: :request do
  let(:wallet) { "0x#{SecureRandom.hex(20)}" }
  let(:player) { create(:player, wallet_address: wallet) }
  let(:token) { TokenService.encode(wallet) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before { player }

  describe "POST /api/v1/matchmaking" do
    subject(:post_matchmaking) { post api_v1_matchmaking_path, params: params, headers: headers }
    let(:params) { { game_type: "logic" } }

    context "without Authorization header" do
      it "returns 401" do
        headers.delete("Authorization")
        post_matchmaking

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("Authentication required")
      end
    end

    context "with a valid token" do
      it "creates a waiting session and returns 201" do
        post_matchmaking

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["session_id"]).to be_present
        expect(body["matchmaking_token"]).to be_present
        expect(body["status"]).to eq("waiting")
        expect(body["matched"]).to be false
        expect(body["vs_cpu"]).to be false
        expect(body["game_type"]).to eq("logic")
      end

      it "matches into an existing waiting session" do
        other_player = create(:player)
        waiting = create(:game_session, game_type: "logic", status: "waiting", player1: other_player)

        post_matchmaking

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["session_id"]).to eq(waiting.id)
        expect(body["matched"]).to be true
        expect(waiting.reload.status).to eq("active")
      end
    end

    context "with an invalid/expired token" do
      it "returns 401" do
        headers["Authorization"] = "Bearer invalid.token.here"
        post_matchmaking

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with missing game_type" do
      it "returns 400" do
        post "/api/v1/matchmaking", params: {}, headers: headers

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
