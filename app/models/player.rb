class Player < ApplicationRecord
  has_many :sessions_as_player1, class_name: "GameSession", foreign_key: :player1_id, dependent: :nullify
  has_many :sessions_as_player2, class_name: "GameSession", foreign_key: :player2_id, dependent: :nullify
  has_many :moves, dependent: :destroy
  has_many :won_results,  class_name: "GameResult", foreign_key: :winner_id, dependent: :nullify
  has_many :lost_results, class_name: "GameResult", foreign_key: :loser_id,  dependent: :nullify

  validates :wallet_address, presence: true, uniqueness: { case_sensitive: false }
  validates :nonce, presence: true

  before_validation :normalize_wallet_address
  before_create     :generate_nonce

  def self.find_or_create_by_wallet(address)
    normalized = address.to_s.downcase
    find_or_create_by!(wallet_address: normalized) { |p| p.nonce = SecureRandom.hex(16) }
  end

  def regenerate_nonce!
    update!(nonce: SecureRandom.hex(16))
  end

  def game_sessions
    GameSession.where("player1_id = ? OR player2_id = ?", id, id)
  end

  private

  def normalize_wallet_address
    self.wallet_address = wallet_address.to_s.downcase
  end

  def generate_nonce
    self.nonce ||= SecureRandom.hex(16)
  end
end
