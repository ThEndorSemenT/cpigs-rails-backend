module Api
  module V1
    class RpcController < ApiController
      skip_before_action :verify_authenticity_token

      ALCHEMY_URL = ENV['ALCHEMY_POLYGON_RPC_URL']

      def polygon
        response = HTTParty.post(
          ALCHEMY_URL,
          body: request.raw_post,
          headers: { 'Content-Type' => 'application/json' }
        )
        render json: response.body, status: response.code
      end
    end
  end
end
