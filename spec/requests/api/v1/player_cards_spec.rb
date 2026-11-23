require "rails_helper"

RSpec.describe "GET /api/v1/players/:wallet/cards", type: :request do
  let(:wallet) { "0x#{'ab' * 20}" }
  let(:path)   { "/api/v1/players/#{wallet}/cards" }

  it "returns the wallet's cards for a simulated request" do
    nft = create(:simulated_nft, wallet_address: wallet, token_id: "7", name: "Pig 7", burn_power: 9)
    create(:simulated_nft) # other wallet
    get path, headers: sim_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include("wallet" => wallet, "collection" => "cpigs-collection-879234287")
    expect(body["cards"]).to eq([{ "id" => nft.id, "token_id" => "7", "name" => "Pig 7",
                                    "image" => "/img.png", "burn_power" => 9, "status" => "available" }])
  end

  it "rejects a malformed wallet" do
    get "/api/v1/players/0x123/cards", headers: sim_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "is 404 without the simulation header (real mode unchanged)" do
    create(:simulated_nft, wallet_address: wallet)
    get path
    expect(response).to have_http_status(:not_found)
  end

  it "is an explicit 403 when the header is sent but simulation is not allowed", :simulation_not_allowed do
    get path, headers: sim_headers
    expect(response).to have_http_status(:forbidden)
  end
end
