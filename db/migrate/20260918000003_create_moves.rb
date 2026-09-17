class CreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves do |t|
      t.bigint  :game_session_id, null: false
      t.bigint  :player_id,       null: false
      t.string  :move_type,       null: false
      t.jsonb   :payload,         null: false, default: {}
      t.integer :sequence,        null: false
      t.timestamps
    end
    add_index :moves, :game_session_id
    add_index :moves, [:game_session_id, :sequence], unique: true
    add_index :moves, [:game_session_id, :player_id, :move_type]
  end
end
