module Api
  module V1
    class PlayersController < ApiController
      # GET /api/v1/players/:wallet_address/nonce
      def nonce
        player = Player.find_or_create_by_wallet(params[:wallet_address])
        render json: { wallet_address: player.wallet_address, nonce: player.nonce }
      end

      # GET /api/v1/players/:wallet_address
      def show
        player = Player.find_by!(wallet_address: params[:wallet_address].downcase)
        render json: { wallet_address: player.wallet_address }
      rescue ActiveRecord::RecordNotFound
        render_error "Player not found", status: :not_found
      end
    end
  end
end
