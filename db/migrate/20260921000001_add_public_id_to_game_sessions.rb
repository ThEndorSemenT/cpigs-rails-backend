class AddPublicIdToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :public_id, :string, limit: 15
    add_index :game_sessions, :public_id, unique: true
  end
end
