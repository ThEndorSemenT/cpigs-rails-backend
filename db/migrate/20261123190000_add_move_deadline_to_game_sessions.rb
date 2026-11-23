class AddMoveDeadlineToGameSessions < ActiveRecord::Migration[8.1]
  def change
    # Set when the session becomes active (human match or CPU fallback).
    add_column :game_sessions, :move_deadline_at, :datetime
    # Sweeper / matcher lookups filter waiting sessions by expires_at.
    add_index :game_sessions, %i[status expires_at], name: "index_game_sessions_on_status_and_expires_at"
    add_index :game_sessions, :move_deadline_at, where: "status IN ('active','playing')",
              name: "index_game_sessions_on_open_move_deadline"
  end
end
