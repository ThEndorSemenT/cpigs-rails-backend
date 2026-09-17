module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_player

    def connect
      self.current_player = find_player
    end

    private

    # Auth via wallet address query param or header.
    # TODO: verify SIWE signature (tech debt — currently trusts the address without proof).
    def find_player
      wallet = request.params[:wallet_address]&.downcase ||
               request.headers["X-Wallet-Address"]&.downcase
      return nil if wallet.blank?
      Player.find_by(wallet_address: wallet)
    end
  end
end
