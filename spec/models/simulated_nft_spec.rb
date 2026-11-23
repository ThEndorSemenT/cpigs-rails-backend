require "rails_helper"

RSpec.describe SimulatedNft, type: :model do
  it "lowercases the wallet and enforces uniqueness per wallet/collection/token" do
    nft = create(:simulated_nft, wallet_address: "0x#{'A' * 40}", token_id: "1")
    expect(nft.wallet_address).to eq("0x#{'a' * 40}")
    dup = build(:simulated_nft, wallet_address: nft.wallet_address, token_id: "1")
    expect(dup).not_to be_valid
  end

  it "rejects unknown status" do
    expect(build(:simulated_nft, status: "bogus")).not_to be_valid
  end
end
