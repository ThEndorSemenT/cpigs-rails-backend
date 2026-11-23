# Fires MATCHMAKING_TIMEOUT_SECONDS after session creation. If the session is still
# waiting, closes the window (CPU fallback or expire — see Matchmaking::HandleTimeout).
# Idempotent: exits if the session is no longer waiting.
module Matchmaking
  class CpuFallbackJob < ApplicationJob
    queue_as :matchmaking

    def perform(session_id)
      session = GameSession.find_by(id: session_id)
      return unless session&.status == "waiting"

      Matchmaking::HandleTimeout.new(session).call
    end
  end
end
