module Api
  module V1
    module Auth
      class SessionsController < ApiController
        skip_before_action :set_current_player, only: [:verify]

        # POST /api/v1/auth/verify
        #
        # Accepts a SIWE-style signed message and verifies wallet ownership.
        # On success returns a bearer token for subsequent requests.
        #
        # Body: { "message": "...", "signature": "0x..." }
        #
        # The message must be the exact string the wallet signed, containing:
        #   - The wallet address
        #   - A nonce previously fetched from /players/:wallet/nonce
        def verify
          message   = params[:message].to_s
          signature = params[:signature].to_s

          return render json: { error: "message and signature required" }, status: :bad_request if message.blank? || signature.blank?

          # Extract the wallet address and nonce from the message before touching crypto
          claimed_address = extract_address(message)
          nonce           = extract_nonce(message)

          return render json: { error: "invalid message format" }, status: :bad_request if claimed_address.blank? || nonce.blank?

          # Recover the signer's address from the signature
          begin
            recovered_pubkey = Eth::Signature.personal_recover(message, signature)
          rescue Eth::Signature::SignatureError
            return render json: { error: "invalid signature" }, status: :unauthorized
          end
          recovered_address = Eth::Util.public_key_to_address(recovered_pubkey).to_s.downcase

          # The recovered address must match the claimed address
          unless recovered_address == claimed_address.downcase
            return render json: { error: "signature does not match wallet" }, status: :unauthorized
          end

          # Find or create the player and verify the nonce
          player = Player.find_or_create_by_wallet(claimed_address)

          unless ActiveSupport::SecurityUtils.secure_compare(player.nonce, nonce)
            return render json: { error: "invalid or expired nonce" }, status: :unauthorized
          end

          # Burn the nonce so it can't be reused
          player.regenerate_nonce!

          token = TokenService.encode(player.wallet_address)

          render json: {
            token: token,
            wallet_address: player.wallet_address
          }
        end

        private

        # Parse wallet address from SIWE-style message.
        # Expected format includes a line like:
        #   "CPigs wants you to sign in with your Ethereum account:\n0xABC..."
        def extract_address(message)
          message.match(/(?:account:\s*\n)(0x[0-9a-fA-F]{40})/i)&.[](1)
        end

        # Parse nonce from message. Looks for "Nonce: <hex>".
        def extract_nonce(message)
          message.match(/Nonce:\s*(\S+)/i)&.[](1)
        end
      end
    end
  end
end
