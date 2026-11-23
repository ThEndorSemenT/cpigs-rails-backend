module Api
  module V1
    module Auth
      # POST /api/v1/auth/simulate  { wallet }   Header: X-Simulation: on
      # Issues a token with claim `sim: true` WITHOUT SIWE. That token is only
      # accepted for simulated requests and simulated sessions (see ApiController
      # and GameSessionsController), so it cannot impersonate a wallet in real games.
      class SimulationsController < ApiController
        skip_before_action :set_current_player
        before_action :require_simulation!
        rate_limit to: 20, within: 1.minute, by: -> { request.remote_ip }, only: :create

        def create
          wallet = params[:wallet].to_s.downcase
          return render_error("Invalid wallet address") unless wallet.match?(Simulation::WALLET_FORMAT)

          player = Player.find_or_create_by_wallet(wallet)
          render json: { token: TokenService.encode(player.wallet_address, sim: true) }
        end

        private

        def require_simulation!
          render_error("Not found", status: :not_found) unless Current.simulation
        end
      end
    end
  end
end
