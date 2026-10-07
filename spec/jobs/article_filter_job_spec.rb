require "rails_helper"

RSpec.describe ArticleFilterJob, type: :job do
  let(:article) { create(:article, status: "pending") }

  describe "#perform" do
    context "when AI is not configured" do
      before { allow_any_instance_of(described_class).to receive(:ai_configured?).and_return(false) }

      it "scores with the keyword filter without ever instantiating AiFilter" do
        expect(AiFilter).not_to receive(:new)

        described_class.perform_now(article.id)

        article.reload
        expect(article.relevance_score).to be >= 0.7
        expect(article.status).to eq("approved")
        expect(article.story_key).to be_present
      end

      it "enqueues a TelegramNotifierJob for the approved article" do
        expect { described_class.perform_now(article.id) }
          .to have_enqueued_job(TelegramNotifierJob).with(article.id)
      end

      it "clusters locally when an approved article has the same title" do
        create(:article,
               status:      "approved",
               language:    article.language,
               title:       article.title,
               story_key:   "minister-arrested-in-bribery-probe",
               published_at: 1.day.ago)

        expect { described_class.perform_now(article.id) }
          .not_to have_enqueued_job(TelegramNotifierJob)

        expect(article.reload.status).to eq("rejected")
        expect(article.story_key).to eq("minister-arrested-in-bribery-probe")
      end
    end

    context "when AI scoring fails with a configuration error (401)" do
      let(:ai) { instance_double(AiFilter) }

      before do
        allow_any_instance_of(described_class).to receive(:ai_configured?).and_return(true)
        allow(AiFilter).to receive(:new).and_return(ai)
        allow(ai).to receive(:score_relevance)
          .and_raise(AiFilter::ConfigurationError, "Relevance scoring failed: 401")
      end

      it "falls back to the keyword filter instead of raising" do
        expect { described_class.perform_now(article.id) }.not_to raise_error

        article.reload
        expect(article.relevance_score).to be >= 0.7
        expect(article.status).to eq("approved")
      end
    end

    context "when AI clustering fails with a configuration error (401)" do
      let(:ai) { instance_double(AiFilter) }

      before do
        allow_any_instance_of(described_class).to receive(:ai_configured?).and_return(true)
        allow(AiFilter).to receive(:new).and_return(ai)
        allow(ai).to receive(:score_relevance).and_return(0.95)
        allow(ai).to receive(:cluster)
          .and_raise(AiFilter::ConfigurationError, "Story clustering failed: 401")
      end

      it "falls back to local clustering instead of raising" do
        expect { described_class.perform_now(article.id) }.not_to raise_error

        article.reload
        expect(article.status).to eq("approved")
        expect(article.story_key).to be_present
      end
    end

    context "when AI fails transiently" do
      let(:ai) { instance_double(AiFilter) }

      before do
        allow_any_instance_of(described_class).to receive(:ai_configured?).and_return(true)
        allow(AiFilter).to receive(:new).and_return(ai)
        allow(ai).to receive(:score_relevance)
          .and_raise(AiFilter::Error, "Relevance scoring failed: connection reset")
      end

      it "re-raises so Sidekiq retries the job" do
        expect { described_class.perform_now(article.id) }.to raise_error(AiFilter::Error)

        expect(article.reload.status).to eq("pending")
      end
    end

    context "when the article is no longer pending" do
      it "skips processing" do
        article.update!(status: "approved")

        expect { described_class.perform_now(article.id) }
          .not_to have_enqueued_job(TelegramNotifierJob)
      end
    end
  end
end
