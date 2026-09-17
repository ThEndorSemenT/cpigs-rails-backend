module Games
  class ResolveSession
    def initialize(session)
      @session = session
    end

    def call
      result = @session.engine.resolve!
      winner = result[:draw] ? nil : result[:winner]
      loser  = result[:draw] ? nil : result[:loser]

      GameSession.transaction do
        @session.resolve!(winner_player: winner, draw: result[:draw])

        game_result = GameResult.create!(
          game_session:      @session,
          winner:            winner,
          loser:             loser,
          draw:              result[:draw],
          blockchain_status: "pending"
        )

        Blockchain::NotifyResultJob.perform_later(game_result.id)
        broadcast_result!(game_result)
      end
    end

    private

    def broadcast_result!(game_result)
      ActionCable.server.broadcast("game_session_#{@session.id}", {
        type:          "game_resolved",
        session_id:    @session.id,
        draw:          game_result.draw,
        winner_wallet: game_result.winner&.wallet_address,
        loser_wallet:  game_result.loser&.wallet_address
      })
    end
  end
end
