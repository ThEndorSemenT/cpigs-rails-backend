# Base for all JSON API controllers — does not serve HTML or use sessions.
# Inherits from ActionController::API (not Base), so browser checks and
# forgery protection do not apply.
class ApiController < ActionController::API
  before_action :resolve_simulation!
  before_action :set_current_player

  private

  # Computed once per request: Current.simulation = signal present AND allowed.
  # A signal when simulation is not allowed is an explicit 403 — never a silent
  # fall back to real mode.
  def resolve_simulation!
    return unless Simulation.signal?(request.headers[Simulation::HEADER])

    unless Simulation.allowed?
      return render_error("Simulation is not allowed in this environment", status: :forbidden)
    end
    Current.simulation = true
  end

  def set_current_player
    token = extract_token_from_header
    return unless token

    payload = TokenService.decode(token)
    return unless payload

    # Simulation tokens carry no proof of wallet ownership: never valid for real requests.
    if payload["sim"] && !Current.simulation
      return render_error("Simulation token is not valid for real requests", status: :unauthorized)
    end

    @current_player = Player.find_by(wallet_address: payload["wallet"]&.downcase)
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
