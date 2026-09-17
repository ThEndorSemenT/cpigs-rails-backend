class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end

# Base for all JSON API controllers — does not serve HTML or use sessions.
class ApiController < ActionController::API
  before_action :set_current_player

  private

  def set_current_player
    wallet = request.headers["X-Wallet-Address"]&.downcase
    @current_player = Player.find_by(wallet_address: wallet) if wallet.present?
  end

  def current_player
    @current_player
  end

  def require_player!
    render json: { error: "Wallet address required" }, status: :unauthorized unless current_player
  end

  def render_error(message, status: :unprocessable_entity)
    render json: { error: message }, status: status
  end
end
