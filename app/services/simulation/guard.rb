module Simulation
  # Defence in depth: call before any code that would touch the chain.
  module Guard
    def self.ensure_chain_allowed!
      raise BlockedError, "Chain access is disabled in simulation mode" if Simulation.enabled?
    end
  end
end
