class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.string  :game_type,         null: false
      t.string  :status,            null: false, default: "waiting"
      t.bigint  :player1_id,        null: false
      t.bigint  :player2_id
      t.bigint  :current_player_id
      t.bigint  :winner_id
      t.boolean :is_vs_cpu,         null: false, default: false
      t.string  :matchmaking_token, null: false
      t.datetime :expires_at
      t.datetime :resolved_at
      t.jsonb   :metadata,          null: false, default: {}
      t.timestamps
    end
    add_index :game_sessions, :matchmaking_token, unique: true
    add_index :game_sessions, :player1_id
    add_index :game_sessions, :player2_id
    add_index :game_sessions, :status
    add_index :game_sessions, [:game_type, :status]
  end
end
