class Move < ApplicationRecord
  belongs_to :game_session
  belongs_to :player

  validates :move_type, presence: true
  validates :payload,   presence: true
  validates :sequence,  presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :sequence,  uniqueness: { scope: :game_session_id }

  scope :for_player, ->(player) { where(player_id: player.id) }
  scope :ordered,    -> { order(:sequence) }
end
