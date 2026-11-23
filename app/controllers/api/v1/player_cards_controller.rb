module Api
  module V1
    # GET /api/v1/players/:wallet_address/cards  (simulated requests only: X-Simulation: on)
    class PlayerCardsController < ApiController
      before_action :require_simulation!

      def index
        wallet = params[:wallet_address].to_s.downcase
        return render_error("Invalid wallet address") unless wallet.match?(Simulation::WALLET_FORMAT)

        collection = Simulation.collection
        cards = SimulatedNft.where(wallet_address: wallet, collection: collection).order(:id)
        render json: {
          wallet:     wallet,
          collection: collection,
          cards:      cards.map do |c|
            { id: c.id, token_id: c.token_id, name: c.name, image: c.image_url,
              burn_power: c.burn_power, status: c.status }
          end
        }
      end

      private

      def require_simulation!
        render_error("Not found", status: :not_found) unless Current.simulation
      end
    end
  end
end
