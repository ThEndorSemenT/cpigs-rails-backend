module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    # Mode of this connection (?simulation=on at handshake).
    def connection_simulation? = connection.try(:simulation) == true

    # Same rule as REST: a session is only reachable from a connection of the same mode.
    def session_mode_matches?(session) = session.simulation? == connection_simulation?
  end
end
