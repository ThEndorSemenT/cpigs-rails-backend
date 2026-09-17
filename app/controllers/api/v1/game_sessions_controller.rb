module Api
  module V1
    # GET  /api/v1/game_sessions/:id
    # POST /api/v1/game_sessions/:id/moves
    # Header: X-Wallet-Address
    class GameSessionsController < ApiController
      before_action :require_player!
      before_action :load_session

      def show
        render json: session_json
      end

      def submit_move
        result = Games::SubmitMove.new(
          session:   @session,
          player:    current_player,
          move_type: params.require(:move_type),
          payload:   params.require(:payload).to_unsafe_h
        ).call

        if result.error
          render_error result.error
        else
          ActionCable.server.broadcast("game_session_#{@session.id}", {
            type:                 "move_received",
            player_wallet:        current_player.wallet_address,
            move_type:            params[:move_type],
            resolution_triggered: result.resolution_triggered
          })
          render json: {
            move_id:              result.move.id,
            sequence:             result.move.sequence,
            resolution_triggered: result.resolution_triggered
          }, status: :created
        end
      end

      private

      def load_session
        @session = GameSession.find_by(id: params[:id] || params[:game_session_id])
        render_error("Session not found", status: :not_found) unless @session
      end

      def session_json
        {
          id:         @session.id,
          game_type:  @session.game_type,
          status:     @session.status,
          is_vs_cpu:  @session.is_vs_cpu,
          player1:    @session.player1.wallet_address,
          player2:    @session.player2&.wallet_address,
          created_at: @session.created_at
        }
      end
    end
  end
end
