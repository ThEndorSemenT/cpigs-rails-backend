module Api
  module V1
    module Auth
      # POST /api/v1/auth/simulate  { wallet }  (simulation mode only)
      # Issues the regular bearer token without SIWE verification.
      class SimulationsController < ApiController
        skip_before_action :set_current_player
        before_action :require_simulation!

        def create
          wallet = params[:wallet].to_s.downcase
          return render_error("Invalid wallet address") unless wallet.match?(Simulation::WALLET_FORMAT)

          player = Player.find_or_create_by_wallet(wallet)
          render json: { token: TokenService.encode(player.wallet_address) }
        end

        private

        def require_simulation!
          render_error("Not found", status: :not_found) unless Simulation.enabled?
        end
      end
    end
  end
end
