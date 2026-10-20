class BackfillGameSessionPublicIds < ActiveRecord::Migration[8.1]
  def up
    say_with_time "Backfilling game session public IDs" do
      GameSession.reset_column_information
      GameSession.where(public_id: nil).find_each do |session|
        session.update_columns(public_id: PublicIdGenerator.generate)
      end
    end

    change_column_null :game_sessions, :public_id, false
  end

  def down
    change_column_null :game_sessions, :public_id, true
  end
end
