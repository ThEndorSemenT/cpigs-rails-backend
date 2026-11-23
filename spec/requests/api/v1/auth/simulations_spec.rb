require "rails_helper"

RSpec.describe "POST /api/v1/auth/simulate", type: :request do
  let(:wallet) { "0x#{'ab' * 20}" }

  it "returns a `sim` token without SIWE for a simulated request" do
    post "/api/v1/auth/simulate", params: { wallet: wallet }, headers: sim_headers
    expect(response).to have_http_status(:ok)
    payload = TokenService.decode(JSON.parse(response.body)["token"])
    expect(payload).to include("wallet" => wallet, "sim" => true)
    expect(Player.find_by(wallet_address: wallet)).to be_present
  end

  it "rejects an invalid wallet" do
    post "/api/v1/auth/simulate", params: { wallet: "nope" }, headers: sim_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "is 404 without the header and creates nothing" do
    post "/api/v1/auth/simulate", params: { wallet: wallet }
    expect(response).to have_http_status(:not_found)
    expect(Player.count).to eq(0)
  end

  it "is 403 when not allowed, creating nothing", :simulation_not_allowed do
    post "/api/v1/auth/simulate", params: { wallet: wallet }, headers: sim_headers
    expect(response).to have_http_status(:forbidden)
    expect(Player.count).to eq(0)
  end
end
