# Base for all JSON API controllers — does not serve HTML or use sessions.
# Inherits from ActionController::API (not Base), so browser checks and
# forgery protection do not apply.
class ApiController < ActionController::API
  before_action :set_current_player

  private

  def set_current_player
    token = extract_token_from_header
    if token
      payload = TokenService.decode(token)
      if payload
        @current_player = Player.find_by(wallet_address: payload["wallet"]&.downcase)
      end
    end
  end

  def current_player
    @current_player
  end

  def require_player!
    render json: { error: "Authentication required" }, status: :unauthorized unless current_player
  end

  def render_error(message, status: :unprocessable_entity)
    render json: { error: message }, status: status
  end

  def extract_token_from_header
    header = request.headers["Authorization"].to_s
    header.match(/^Bearer\s+(.+)$/i)&.[](1)
  end
end
