module Api
  module V1
    class RpcController < ApiController
      # Note: No need to skip verify_authenticity_token since ApiController
      # inherits from ActionController::API which doesn't include CSRF protection

      ALCHEMY_URL = ENV['ALCHEMY_POLYGON_RPC_URL']

      def polygon
        response = Faraday.post(
          ALCHEMY_URL,
          request.raw_post,
          { 'Content-Type' => 'application/json' }
        )

        render json: response.body, status: response.status
      end
    end
  end
end
