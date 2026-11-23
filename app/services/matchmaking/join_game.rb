module Matchmaking
  class JoinGame
    Result = Struct.new(:session, :matched, keyword_init: true)

    def initialize(player:, game_type:, simulation: false)
      @player     = player
      @game_type  = game_type
      @simulation = simulation
    end

    def call
      session = GameSession.find_or_create_for_matchmaking(
        player: @player, game_type: @game_type, simulation: @simulation
      )

      if session.player2_id.present? || session.is_vs_cpu?
        Result.new(session: session, matched: true)
      else
        # Newly created session — schedule the timeout trigger. A re-join that returned
        # the player's existing waiting session already has one scheduled (the sweeper
        # covers it otherwise).
        if session.previously_new_record?
          Matchmaking::CpuFallbackJob.set(
            wait_until: session.expires_at
          ).perform_later(session.id)
        end
        Result.new(session: session, matched: false)
      end
    end
  end
end
