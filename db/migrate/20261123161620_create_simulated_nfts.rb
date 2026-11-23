class CreateSimulatedNfts < ActiveRecord::Migration[8.1]
  def change
    create_table :simulated_nfts do |t|
      t.string  :wallet_address, null: false
      t.string  :collection,     null: false
      t.string  :token_id,       null: false
      t.string  :name
      t.string  :image_url
      t.integer :burn_power,     null: false, default: 0
      t.string  :status,         null: false, default: "available"
      t.jsonb   :metadata,       null: false, default: {}

      t.timestamps
    end
    add_index :simulated_nfts, :wallet_address
    add_index :simulated_nfts, %i[wallet_address collection token_id],
              unique: true, name: "index_simulated_nfts_on_wallet_collection_token"
  end
end
