require "rails_helper"

RSpec.describe KeywordFilter do
  describe ".score_relevance" do
    it "scores an article with a high-tier corruption keyword near 1.0" do
      score, matched = described_class.score_relevance(
        build(:article, title: "Kickback scheme uncovered", description: nil, content: nil)
      )

      expect(score).to eq(1.0)
      expect(matched).to include("kickback")
    end

    it "scores an English corruption article above the threshold" do
      score, matched = described_class.score_relevance(
        build(:article, language: "en",
              title: "Mayor arrested on bribery charges",
              description: "Prosecutor said the official took cash bribes.",
              content: nil)
      )

      expect(score).to be >= 0.7
      expect(matched).to include("bribery")
    end

    it "rejects generic political news that has no corruption signals" do
      score, _matched = described_class.score_relevance(
        build(:article,
              title: "Senador reafirma apoio a candidato no segundo turno",
              description: "O governador eleito afirmou que vai apoiar o candidato à Presidência.",
              content: nil)
      )

      expect(score).to be < Rails.application.config_for(:news_bot)[:relevance_threshold].to_f
    end

    it "rejects financial/market news with no corruption signals" do
      score, _matched = described_class.score_relevance(
        build(:article, language: "en",
              title: "Stock market hits record high after election rally",
              description: "Banks led the rally while exporters lagged.",
              content: nil)
      )

      expect(score).to eq(0.0)
    end

    it "returns [0.0, []] for blank text" do
      score, matched = described_class.score_relevance(
        build(:article, title: nil, description: nil, content: nil)
      )

      expect(score).to eq(0.0)
      expect(matched).to be_empty
    end

    it "reports all matched keywords" do
      score, matched = described_class.score_relevance(
        build(:article,
              title: "Ministério público indicia réu por lavagem de dinheiro",
              description: nil, content: nil)
      )

      expect(matched).to include("ministério público", "réu", "lavagem de dinheiro")
      expect(score).to be > 0.7
    end
  end
end
