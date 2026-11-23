require "rails_helper"

RSpec.describe "GET /api/v1/players/:wallet/cards", type: :request do
  let(:wallet) { "0x#{'ab' * 20}" }

  context "when simulation is on", :simulation do
    it "returns the wallet's cards" do
      nft = create(:simulated_nft, wallet_address: wallet, token_id: "7", name: "Pig 7", burn_power: 9)
      create(:simulated_nft) # other wallet
      get "/api/v1/players/#{wallet.upcase.sub('0X', '0x')}/cards"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include("wallet" => wallet, "collection" => "cpigs-collection-879234287")
      expect(body["cards"]).to eq([{ "id" => nft.id, "token_id" => "7", "name" => "Pig 7",
                                      "image" => "/img.png", "burn_power" => 9, "status" => "available" }])
    end

    it "rejects a malformed wallet" do
      get "/api/v1/players/0x123/cards"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it "is 404 when simulation is off" do
    create(:simulated_nft, wallet_address: wallet)
    get "/api/v1/players/#{wallet}/cards"
    expect(response).to have_http_status(:not_found)
  end
end
