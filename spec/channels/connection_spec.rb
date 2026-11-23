require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:wallet) { "0x#{'ab' * 20}" }
  let!(:player) { create(:player, wallet_address: wallet) }

  it "accepts a real token without the signal" do
    connect "/cable", params: { token: TokenService.encode(wallet) }
    expect(connection.current_player).to eq(player)
    expect(connection.simulation).to be(false)
  end

  it "accepts a sim token with ?simulation=on" do
    connect "/cable", params: { token: TokenService.encode(wallet, sim: true), simulation: "on" }
    expect(connection.simulation).to be(true)
  end

  it "rejects a sim token without the signal" do
    expect { connect "/cable", params: { token: TokenService.encode(wallet, sim: true) } }
      .to have_rejected_connection
  end

  it "rejects the signal when simulation is not allowed", :simulation_not_allowed do
    expect { connect "/cable", params: { token: TokenService.encode(wallet), simulation: "on" } }
      .to have_rejected_connection
  end
end
