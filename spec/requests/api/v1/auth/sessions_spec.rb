require "rails_helper"

RSpec.describe "Api::V1::Auth::Sessions", type: :request do
  let(:key) { Eth::Key.new }
  let(:wallet) { key.address.to_s.downcase }
  let!(:player) { create(:player, wallet_address: wallet) }

  def build_siwe_message(address, nonce)
    <<~MSG.strip
      CPigs wants you to sign in with your Ethereum account:
      #{address}

      Nonce: #{nonce}
    MSG
  end

  describe "POST /api/v1/auth/verify" do
    subject(:verify) do
      post "/api/v1/auth/verify", params: { message: message, signature: signature }
    end

    let(:message) { build_siwe_message(wallet, player.nonce) }
    let(:signature) { key.personal_sign(message) }

    context "with a valid signature" do
      it "returns a token and wallet address" do
        verify

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["token"]).to be_present
        expect(body["wallet_address"].downcase).to eq(wallet)
      end

      it "regenerates the nonce so it cannot be replayed" do
        old_nonce = player.nonce
        verify
        expect(player.reload.nonce).not_to eq(old_nonce)
      end
    end

    context "with a forged signature (wrong wallet)" do
      it "returns 401" do
        other_key = Eth::Key.new
        # Message claims the original player's wallet, but is signed by a different key
        message = build_siwe_message(wallet, player.nonce)
        sig = other_key.personal_sign(message)

        post "/api/v1/auth/verify", params: { message: message, signature: sig }

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("signature does not match wallet")
      end
    end

    context "with a reused nonce" do
      it "returns 401 after the first use" do
        verify
        expect(response).to have_http_status(:ok)

        post "/api/v1/auth/verify", params: { message: message, signature: signature }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("invalid or expired nonce")
      end
    end

    context "with missing params" do
      it "returns 400 when message is missing" do
        post "/api/v1/auth/verify", params: { signature: "0xabc" }
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when signature is missing" do
        post "/api/v1/auth/verify", params: { message: "some message" }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with a malformed message" do
      it "returns 400" do
        post "/api/v1/auth/verify", params: { message: "garbage", signature: "0xabc" }
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)["error"]).to eq("invalid message format")
      end
    end
  end
end
