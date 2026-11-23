module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_player, :simulation

    # Handshake: wss://…/cable?token=…&simulation=on
    def connect
      self.simulation = Simulation.signal?(request.params[:simulation])
      # Asked for simulation but not allowed here: refuse, never fall back to real.
      reject_unauthorized_connection if simulation && !Simulation.allowed?

      self.current_player = find_player
      reject_unauthorized_connection unless current_player
    end

    private

    # Auth via Bearer token in Sec-WebSocket-Protocol or query param.
    def find_player
      token = request.params[:token] ||
              extract_token_from_protocol
      return nil if token.blank?

      payload = TokenService.decode(token)
      return nil if payload.blank?
      # `sim` tokens (no wallet proof) are only valid on simulated connections.
      return nil if payload["sim"] && !simulation

      Player.find_by(wallet_address: payload["wallet"]&.downcase)
    end

    def extract_token_from_protocol
      protocols = request.headers["Sec-WebSocket-Protocol"].to_s.split(", ")
      token_protocol = protocols.find { |p| p.start_with?("auth.") }
      token_protocol&.split(".", 2)&.[](1)
    end
  end
end
