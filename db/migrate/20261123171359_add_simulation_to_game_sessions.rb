class AddSimulationToGameSessions < ActiveRecord::Migration[8.1]
  def change
    # Source of truth for simulation: set at creation, read by jobs/services/channels.
    add_column :game_sessions, :simulation, :boolean, default: false, null: false
    add_index  :game_sessions, %i[status game_type simulation], name: "index_game_sessions_matchmaking_pool"
  end
end
