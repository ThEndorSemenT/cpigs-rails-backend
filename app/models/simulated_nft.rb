# NFT ownership used instead of the chain while simulation mode is on.
class SimulatedNft < ApplicationRecord
  STATUSES = %w[available locked lost].freeze

  validates :wallet_address, :collection, :token_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :token_id, uniqueness: { scope: %i[wallet_address collection] }

  before_validation { self.wallet_address = wallet_address.to_s.downcase }

  scope :for_wallet, ->(wallet) { where(wallet_address: wallet.to_s.downcase) }
end
