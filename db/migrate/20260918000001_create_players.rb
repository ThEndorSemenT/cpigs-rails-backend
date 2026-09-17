class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :wallet_address, null: false
      t.string :display_name
      t.string :nonce, null: false
      t.timestamps
    end
    add_index :players, :wallet_address, unique: true
    add_index :players, :nonce
  end
end
