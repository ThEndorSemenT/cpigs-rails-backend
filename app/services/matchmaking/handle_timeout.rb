module Matchmaking
  # Closes the matchmaking window of one session. Shared by CpuFallbackJob (exact
  # trigger) and ExpireStaleJob (sweeper safety net), so both are idempotent and
  # safe to run concurrently or twice: the row is locked and the status rechecked.
  #
  # Product switch: MATCHMAKING_CPU_FALLBACK=false → expire + broadcast `expired`
  # instead of playing against the CPU. Default (true) keeps the current behaviour.
  # TODO(simulation/bot): for `session.simulation?` use a bot Player — docs/SIMULATION.md.
  class HandleTimeout
    def self.cpu_fallback_enabled?
      ENV.fetch("MATCHMAKING_CPU_FALLBACK", "true") != "false"
    end

    def initialize(session)
      @session = session
    end

    def call
      return false unless @session

      return @session.expire!(reason: "timeout") unless self.class.cpu_fallback_enabled?

      @session.with_lock do
        next false unless @session.status == "waiting"

        engine = @session.engine
        @session.metadata["cpu_moves"] = engine.cpu_moves.each_with_index.map do |cpu_move, idx|
          cpu_move.merge(sequence: idx + 1)
        end
        @session.fall_back_to_cpu! # persists metadata too; broadcasts `matched` after commit
        true
      end
    end
  end
end
