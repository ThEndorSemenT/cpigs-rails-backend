require "rails_helper"

RSpec.describe Api::V1::RpcController, type: :request do
  describe "POST /api/v1/rpc/polygon" do
    let(:rpc_url) { "https://polygon-mainnet.g.alchemy.com/v2/test-key" }
    let(:rpc_request_body) { { jsonrpc: "2.0", method: "eth_blockNumber", params: [], id: 1 }.to_json }
    let(:rpc_response_body) { { jsonrpc: "2.0", id: 1, result: "0x1234" }.to_json }
    let(:faraday_response) { instance_double(Faraday::Response, body: rpc_response_body, status: 200) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ALCHEMY_POLYGON_RPC_URL").and_return(rpc_url)
      allow(Faraday).to receive(:post).and_return(faraday_response)
    end

    it "proxies the request to Alchemy and returns the response" do
      post api_v1_rpc_polygon_path, params: rpc_request_body, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(JSON.parse(rpc_response_body))
    end

    it "forwards the request body to Alchemy" do
      post api_v1_rpc_polygon_path, params: rpc_request_body, headers: { "Content-Type" => "application/json" }

      expect(Faraday).to have_received(:post).with(
        rpc_url,
        rpc_request_body,
        { "Content-Type" => "application/json" }
      )
    end

    context "in simulation mode", :simulation do
      it "returns 403 and never calls Alchemy, even for eth_sendRawTransaction" do
        body = { jsonrpc: "2.0", method: "eth_sendRawTransaction", params: ["0xdead"], id: 1 }.to_json
        post api_v1_rpc_polygon_path, params: body, headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:forbidden)
        expect(Faraday).not_to have_received(:post)
      end
    end

    context "when the RPC endpoint is not configured" do
      before do
        allow(ENV).to receive(:[]).with("ALCHEMY_POLYGON_RPC_URL").and_return(nil)
      end

      it "returns 503 without calling Alchemy" do
        post api_v1_rpc_polygon_path, params: rpc_request_body, headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:service_unavailable)
        expect(Faraday).not_to have_received(:post)
      end
    end

    context "when Alchemy returns an error" do
      let(:faraday_response) { instance_double(Faraday::Response, body: { error: "Internal Server Error" }.to_json, status: 500) }

      it "returns the error status from Alchemy" do
        post api_v1_rpc_polygon_path, params: rpc_request_body, headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
