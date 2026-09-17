module Api
  module V1
    class HealthController < ApiController
      def show
        render json: { status: "ok", time: Time.current }
      end
    end
  end
end
