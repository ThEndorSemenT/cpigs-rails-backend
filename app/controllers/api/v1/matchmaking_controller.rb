module Api
  module V1
    # POST /api/v1/matchmaking
    # Body: { game_type: "logic" }
    # Header: X-Wallet-Address
    class MatchmakingController < ApiController
      before_action :require_player!

      def create
        game_type = params.require(:game_type)
        result = Matchmaking::JoinGame.new(player: current_player, game_type: game_type).call
        session = result.session
        render json: {
          session_id:        session.id,
          matchmaking_token: session.matchmaking_token,
          status:            session.status,
          matched:           result.matched,
          vs_cpu:            session.is_vs_cpu,
          game_type:         session.game_type
        }, status: :created
      rescue ArgumentError => e
        render_error e.message
      rescue ActiveRecord::RecordInvalid => e
        render_error e.message
      end
    end
  end
end
