require "rails_helper"

RSpec.describe Simulation::AssignCards do
  let(:wallet) { "0x#{'AB' * 20}" }
  let(:addr)   { wallet.downcase }

  it "assigns random catalog tokens to the (lowercased) wallet" do
    result = described_class.call(wallet: wallet, count: 10, collection: "cpigs-collection-879234287")
    expect(result.assigned.size).to eq(10)
    expect(SimulatedNft.where(wallet_address: addr).count).to eq(10)
    expect(SimulatedNft.first.burn_power).to be_between(1, 15)
  end

  it "is idempotent: never reassigns tokens already owned and is bounded by the catalog" do
    described_class.call(wallet: wallet, count: 20)
    described_class.call(wallet: wallet, count: 20)
    expect(SimulatedNft.where(wallet_address: addr).count).to eq(30)
    third = described_class.call(wallet: wallet, count: 5)
    expect(third.assigned).to be_empty
    expect(SimulatedNft.where(wallet_address: addr).count).to eq(30)
  end

  it "does not duplicate across repeated runs of the same count" do
    2.times { described_class.call(wallet: wallet, count: 10) }
    ids = SimulatedNft.where(wallet_address: addr).pluck(:token_id)
    expect(ids.size).to eq(20)
    expect(ids.uniq.size).to eq(20)
  end

  it "validates wallet, count and collection" do
    expect { described_class.call(wallet: "0xabc", count: 1) }.to raise_error(ArgumentError, /wallet/)
    expect { described_class.call(wallet: wallet, count: 0) }.to raise_error(ArgumentError, /count/)
    expect { described_class.call(wallet: wallet, count: 1, collection: "nope") }
      .to raise_error(Simulation::Catalog::UnknownCollection)
    expect { described_class.call(wallet: wallet, count: 1, collection: "../secrets") }
      .to raise_error(Simulation::Catalog::UnknownCollection)
  end
end
