module Simulation
  # Checks that submitted cards ({ "token_id", "burn_power" }) belong to the wallet.
  # Cards must be distinct, `available`, and burn_power must match the stored value.
  module CardOwnership
    def self.valid?(wallet:, cards:, collection: Simulation.collection)
      ids = cards.map { |c| c["token_id"].to_s }
      return false if ids.uniq.size != ids.size

      owned = SimulatedNft.where(wallet_address: wallet.to_s.downcase, collection: collection,
                                 token_id: ids, status: "available").pluck(:token_id, :burn_power).to_h
      cards.all? { |c| owned[c["token_id"].to_s] == c["burn_power"] }
    end
  end
end
