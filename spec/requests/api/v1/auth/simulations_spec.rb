require "rails_helper"

RSpec.describe "POST /api/v1/auth/simulate", type: :request do
  let(:wallet) { "0x#{'ab' * 20}" }

  context "when simulation is on", :simulation do
    it "creates the player and returns a valid token without SIWE" do
      post "/api/v1/auth/simulate", params: { wallet: wallet }
      expect(response).to have_http_status(:ok)
      token = JSON.parse(response.body)["token"]
      expect(TokenService.decode(token)["wallet"]).to eq(wallet)
      expect(Player.find_by(wallet_address: wallet)).to be_present
    end

    it "rejects an invalid wallet" do
      post "/api/v1/auth/simulate", params: { wallet: "nope" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it "is 404 when simulation is off and creates nothing" do
    post "/api/v1/auth/simulate", params: { wallet: wallet }
    expect(response).to have_http_status(:not_found)
    expect(Player.count).to eq(0)
  end
end
