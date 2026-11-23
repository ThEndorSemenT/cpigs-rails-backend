# Fires MATCHMAKING_TIMEOUT_SECONDS after session creation.
# If still waiting → fall back to CPU, inject CPU moves into metadata, notify P1.
# TODO(simulation/bot): for `session.simulation?` use a bot Player (BOT_WALLET_ADDRESS)
# holding cards from Simulation::AssignCards and submit its moves via
# Games::SubmitMove — see docs/SIMULATION.md. Do not read config/Current here.
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
        type: "matched", vs_cpu: true, session_id: session.to_param
      })
    end
  end
end
