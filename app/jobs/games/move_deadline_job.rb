# Enqueued for `move_deadline_at` when a session becomes active. If moves are still
# pending then, the session is expired (forfeit). Idempotent.
module Games
  class MoveDeadlineJob < ApplicationJob
    queue_as :game_resolution

    def perform(session_id)
      session = GameSession.find_by(id: session_id)
      return unless session&.move_deadline_at && session.move_deadline_at.past?

      session.expire!(reason: "move_timeout", from: %w[active playing])
    end
  end
end
