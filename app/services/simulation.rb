# Namespace for simulation mode (no chain, NFTs in simulated_nfts).
#
# Who decides: the client asks per request (X-Simulation: on / ?simulation=on);
# the backend only obeys when simulation is *allowed* in this environment.
# The decision is persisted on GameSession#simulation, the source of truth for
# jobs, services and channels.
module Simulation
  class BlockedError < StandardError; end

  WALLET_FORMAT = /\A0x[0-9a-fA-F]{40}\z/
  HEADER        = "X-Simulation"

  # Single permission seam. To move to Flipper (flipper-active_record, no Redis)
  # change only this method, e.g. `Flipper.enabled?(:simulation)`.
  def self.allowed?
    Rails.application.config.x.simulation_allowed == true
  end

  # Whether a raw header / query value asks for simulation.
  def self.signal?(value)
    value.to_s.strip.casecmp?("on")
  end

  def self.collection
    Rails.application.config.x.simulation_collection
  end
end
