module Simulation
  # Defence in depth: call before any code that would touch the chain.
  # `context` is a GameSession, or a boolean (e.g. Current.simulation).
  module Guard
    def self.ensure_chain_allowed!(context)
      simulated = context.respond_to?(:simulation?) ? context.simulation? : context
      raise BlockedError, "Chain access is disabled for simulated requests/sessions" if simulated
    end
  end
end
