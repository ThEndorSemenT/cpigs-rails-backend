# Namespace + feature flag for simulation mode (no chain, NFTs in simulated_nfts).
module Simulation
  class BlockedError < StandardError; end

  WALLET_FORMAT = /\A0x[0-9a-fA-F]{40}\z/

  def self.enabled?
    Rails.application.config.x.simulation_mode == true
  end

  def self.collection
    Rails.application.config.x.simulation_collection
  end
end
