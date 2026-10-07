require "rails_helper"

RSpec.describe AiFilter do
  let(:article) { build(:article) }
  let(:client)  { instance_double(OpenAI::Client) }

  before { allow(OpenAI::Client).to receive(:new).and_return(client) }

  describe "error classification" do
    context "when the API rejects the key (401)" do
      before do
        error = Faraday::UnauthorizedError.new(
          "the server responded with status 401 for POST https://api.openai.com/v1/chat/completions",
          { status: 401 }
        )
        allow(client).to receive(:chat).and_raise(error)
      end

      it "raises a non-retryable ConfigurationError from score_relevance" do
        expect { described_class.new.score_relevance(article) }
          .to raise_error(AiFilter::ConfigurationError, /Relevance scoring failed/)
      end

      it "raises a non-retryable ConfigurationError from cluster" do
        expect { described_class.new.cluster(article, [[1, "key", "Title"]]) }
          .to raise_error(AiFilter::ConfigurationError, /Story clustering failed/)
      end
    end

    context "when the request fails transiently" do
      before do
        allow(client).to receive(:chat)
          .and_raise(Faraday::ConnectionFailed, "connection reset by peer")
      end

      it "raises a retryable Error from score_relevance" do
        expect { described_class.new.score_relevance(article) }.to raise_error(AiFilter::Error) do |error|
          expect(error).not_to be_a(AiFilter::ConfigurationError)
        end
      end

      it "raises a retryable Error from cluster" do
        expect { described_class.new.cluster(article, [[1, "key", "Title"]]) }.to raise_error(AiFilter::Error) do |error|
          expect(error).not_to be_a(AiFilter::ConfigurationError)
        end
      end
    end
  end

  describe "#cluster" do
    context "with no recent articles" do
      it "returns a slug without calling the API" do
        expect(client).not_to receive(:chat)

        result = described_class.new.cluster(article, [])

        expect(result).to eq(
          story_key:     "minister-arrested-in-bribery-probe",
          superseded_id: nil,
          supersede:     false,
          duplicate:     false
        )
      end
    end
  end
end
