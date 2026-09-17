# Fires MATCHMAKING_TIMEOUT_SECONDS after session creation.
# If still waiting → fall back to CPU, inject CPU moves into metadata, notify P1.
module Matchmaking
  class CpuFallbackJob < ApplicationJob
    queue_as :matchmaking

    def perform(session_id)
      session = GameSession.find_by(id: session_id)
      return unless session&.status == "waiting"

      session.transaction do
        session.fall_back_to_cpu!
        engine = session.engine
        engine.cpu_moves.each_with_index do |cpu_move, idx|
          session.metadata["cpu_moves"] ||= []
          session.metadata["cpu_moves"] << cpu_move.merge(sequence: idx + 1)
        end
        session.save!
      end

      ActionCable.server.broadcast("matchmaking_#{session.matchmaking_token}", {
        type: "matched", vs_cpu: true, session_id: session.id
      })
    end
  end
end
