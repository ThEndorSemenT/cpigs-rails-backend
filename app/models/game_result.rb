class GameResult < ApplicationRecord
  BLOCKCHAIN_STATUSES = %w[pending notified failed skipped].freeze

  belongs_to :game_session
  belongs_to :winner, class_name: "Player", optional: true
  belongs_to :loser,  class_name: "Player", optional: true

  validates :blockchain_status, inclusion: { in: BLOCKCHAIN_STATUSES }
  validates :game_session_id,   uniqueness: true

  scope :pending_blockchain, -> { where(blockchain_status: "pending") }
  scope :failed_blockchain,  -> { where(blockchain_status: "failed") }

  def mark_notified!(tx_data = {})
    update!(blockchain_status: "notified", blockchain_tx_data: tx_data, blockchain_notified_at: Time.current)
  end

  def mark_failed!(error_info = {})
    update!(blockchain_status: "failed", blockchain_tx_data: error_info)
  end

  def skip_blockchain!
    update!(blockchain_status: "skipped")
  end
end
