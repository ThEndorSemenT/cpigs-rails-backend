require "rails_helper"

RSpec.describe GameSessionChannel, type: :channel do
  let(:player)       { create(:player) }
  let(:real_session) { create(:game_session, player1: player) }
  let(:sim_session)  { create(:game_session, player1: player, simulation: true) }

  it "matches connection mode and session mode" do
    stub_connection(current_player: player, simulation: true)
    subscribe(session_id: sim_session.to_param)
    expect(subscription).to be_confirmed
    subscribe(session_id: real_session.to_param)
    expect(subscription).to be_rejected
  end

  it "rejects a real connection on a simulated session" do
    stub_connection(current_player: player, simulation: false)
    subscribe(session_id: sim_session.to_param)
    expect(subscription).to be_rejected
  end
end
