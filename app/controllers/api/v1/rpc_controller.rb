module Api
  module V1
    class RpcController < ApiController
      # Note: No need to skip verify_authenticity_token since ApiController
      # inherits from ActionController::API which doesn't include CSRF protection

      def polygon
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

      def rpc_url
        ENV["ALCHEMY_POLYGON_RPC_URL"].presence
      end
    end
  end
end
