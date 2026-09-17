module Matchmaking
  class JoinGame
    Result = Struct.new(:session, :matched, keyword_init: true)

    def initialize(player:, game_type:)
      @player    = player
      @game_type = game_type
    end

    def call
      session = GameSession.find_or_create_for_matchmaking(player: @player, game_type: @game_type)

      if session.player2_id.present? || session.is_vs_cpu?
        Result.new(session: session, matched: true)
      else
        # New session — schedule the CPU fallback timer
        Matchmaking::CpuFallbackJob.set(
          wait: GameSession::MATCHMAKING_TIMEOUT_SECONDS.seconds
        ).perform_later(session.id)
        Result.new(session: session, matched: false)
      end
    end
  end
end
