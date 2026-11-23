module Api
  module V1
    # GET  /api/v1/game_sessions/:id
    # POST /api/v1/game_sessions/:id/moves
    # Header: Authorization: Bearer <token>
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
          body = {
            move_id:              result.move.id,
            sequence:             result.move.sequence,
            resolution_triggered: result.resolution_triggered
          }
          body[:result] = result_json(result.game_result) if result.game_result
          render json: body, status: :created
        end
      end

      private

      def result_json(game_result)
        {
          draw:          game_result.draw,
          winner_wallet: game_result.winner&.wallet_address,
          loser_wallet:  game_result.loser&.wallet_address
        }
      end

      def load_session
        @session = GameSession.find_by_param(params[:id] || params[:game_session_id])
        # A session is only reachable by requests of the same mode. This is what
        # stops `sim` tokens (no wallet proof) from touching real sessions, and
        # real-mode requests from touching simulated ones.
        unless @session && @session.simulation? == Current.simulation
          render_error("Session not found", status: :not_found)
        end
      end

      def session_json
        {
          id:         @session.to_param,
          public_id:  @session.public_id,
          game_type:  @session.game_type,
          simulation: @session.simulation?,
          status:     @session.status,
          is_vs_cpu:  @session.is_vs_cpu,
          player1:    @session.player1.wallet_address,
          player2:    @session.player2&.wallet_address,
          created_at: @session.created_at
        }.merge(@session.timing_json)
      end
    end
  end
end
