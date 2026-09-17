# Interface every game engine must implement.
module Games
  class BaseEngine
    attr_reader :session

    def initialize(session)
      @session = session
    end

    def valid_move?(player, move_type, payload) = raise NotImplementedError
    def all_moves_submitted?                    = raise NotImplementedError
    def resolve!                                = raise NotImplementedError  # → { winner:, loser:, draw: }
    def cpu_moves                               = raise NotImplementedError  # → [{ move_type:, payload: }]

    protected

    def player1; session.player1 end
    def player2; session.player2 end

    def moves_by(player)
      session.moves.for_player(player).ordered
    end

    def move_payload(player, move_type)
      session.moves.find_by(player_id: player.id, move_type: move_type)&.payload
    end
  end
end
