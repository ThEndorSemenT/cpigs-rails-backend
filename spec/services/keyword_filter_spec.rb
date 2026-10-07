require "rails_helper"

RSpec.describe KeywordFilter do
  describe ".score_relevance" do
    it "returns a score above the default relevance threshold" do
      score, = described_class.score_relevance(build(:article, title: "Corruption scandal unfolds"))

      expect(score).to eq(0.71)
      expect(score).to be >= Rails.application.config_for(:news_bot)[:relevance_threshold].to_f
    end

    it "reports the keywords it matched" do
      _, matched = described_class.score_relevance(
        build(:article, title: "Kickback scheme uncovered", description: nil, content: nil)
      )

      expect(matched).to include("kickback")
    end

    it "returns an empty match list for unrelated text" do
      score, matched = described_class.score_relevance(
        build(:article, title: "Sunny weather today", description: nil, content: nil)
      )

      expect(score).to eq(0.71)
      expect(matched).to be_empty
    end
  end
end
