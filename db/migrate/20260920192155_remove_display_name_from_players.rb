class RemoveDisplayNameFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :display_name, :string
  end
end
