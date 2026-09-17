module Games
  class SubmitMove
    Result = Struct.new(:move, :resolution_triggered, :error, keyword_init: true)

    def initialize(session:, player:, move_type:, payload:)
      @session   = session
      @player    = player
      @move_type = move_type
      @payload   = payload
    end

    def call
      unless %w[active playing].include?(@session.status)
        return error("Session is not accepting moves (status: #{@session.status})")
      end
      unless participant?
        return error("Player is not a participant in this session")
      end

      engine = @session.engine
      unless engine.valid_move?(@player, @move_type, @payload)
        return error("Invalid move payload for #{@move_type}")
      end
      if move_already_submitted?
        return error("Move #{@move_type} already submitted by this player")
      end

      move = persist_move!
      @session.start_playing! if @session.status == "active"

      if engine.all_moves_submitted?
        @session.begin_resolution!
        Games::ResolveSessionJob.perform_later(@session.id)
        Result.new(move: move, resolution_triggered: true, error: nil)
      else
        Result.new(move: move, resolution_triggered: false, error: nil)
      end
    end

    private

    def participant?
      @session.player1_id == @player.id ||
        (@session.player2_id.present? && @session.player2_id == @player.id)
    end

    def move_already_submitted?
      @session.moves.exists?(player_id: @player.id, move_type: @move_type)
    end

    def persist_move!
      next_seq = (@session.moves.maximum(:sequence) || 0) + 1
      @session.moves.create!(player: @player, move_type: @move_type, payload: @payload, sequence: next_seq)
    end

    def error(message)
      Result.new(move: nil, resolution_triggered: false, error: message)
    end
  end
end
