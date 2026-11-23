require "rails_helper"

RSpec.describe Simulation::Guard do
  it "raises BlockedError for a simulated session or truthy context" do
    expect { described_class.ensure_chain_allowed!(build(:game_session, simulation: true)) }
      .to raise_error(Simulation::BlockedError)
    expect { described_class.ensure_chain_allowed!(true) }.to raise_error(Simulation::BlockedError)
  end

  it "is a no-op for real sessions / contexts" do
    expect { described_class.ensure_chain_allowed!(build(:game_session)) }.not_to raise_error
    expect { described_class.ensure_chain_allowed!(false) }.not_to raise_error
  end
end
