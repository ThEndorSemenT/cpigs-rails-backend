require "rails_helper"

RSpec.describe Simulation do
  it ".allowed? follows config (true by default in test)" do
    expect(described_class.allowed?).to be(true)
  end

  it ".allowed? is false when not allowed", :simulation_not_allowed do
    expect(described_class.allowed?).to be(false)
  end

  it ".signal? only accepts `on` (case-insensitive)" do
    expect(described_class.signal?("on")).to be(true)
    expect(described_class.signal?(" ON ")).to be(true)
    [nil, "", "off", "true", "1"].each { |v| expect(described_class.signal?(v)).to be(false) }
  end
end
