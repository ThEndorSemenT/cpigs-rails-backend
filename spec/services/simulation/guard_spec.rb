require "rails_helper"

RSpec.describe Simulation::Guard do
  it "raises BlockedError in simulation", :simulation do
    expect { described_class.ensure_chain_allowed! }.to raise_error(Simulation::BlockedError)
  end

  it "is a no-op in real mode" do
    expect { described_class.ensure_chain_allowed! }.not_to raise_error
  end
end
