module Api
  module V1
    class RpcController < ApiController
      # Note: No need to skip verify_authenticity_token since ApiController
      # inherits from ActionController::API which doesn't include CSRF protection

      before_action :block_in_simulation!

      def polygon
        Simulation::Guard.ensure_chain_allowed!

        unless rpc_url.present?
          return render json: { error: "RPC endpoint not configured" }, status: :service_unavailable
        end

        response = Faraday.post(
          rpc_url,
          request.raw_post,
          { "Content-Type" => "application/json" }
        )

        render json: response.body, status: response.status
      end

      private

      def block_in_simulation!
        render json: { error: "Chain access is disabled in simulation mode" }, status: :forbidden if Simulation.enabled?
      end

      def rpc_url
        ENV["ALCHEMY_POLYGON_RPC_URL"].presence
      end
    end
  end
end
