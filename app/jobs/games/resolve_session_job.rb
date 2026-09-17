module Games
  class ResolveSessionJob < ApplicationJob
    queue_as :game_resolution

    def perform(session_id)
      session = GameSession.find_by(id: session_id)
      return unless session&.status == "resolving"
      Games::ResolveSession.new(session).call
    end
  end
end
