class CreateGameResults < ActiveRecord::Migration[8.1]
  def change
    create_table :game_results do |t|
      t.bigint  :game_session_id,       null: false
      t.bigint  :winner_id
      t.bigint  :loser_id
      t.boolean :draw,                  null: false, default: false
      t.string  :blockchain_status,     null: false, default: "pending"
      t.jsonb   :blockchain_tx_data,    default: {}
      t.datetime :blockchain_notified_at
      t.timestamps
    end
    add_index :game_results, :game_session_id, unique: true
    add_index :game_results, :blockchain_status
  end
end
