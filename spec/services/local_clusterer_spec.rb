require "rails_helper"

RSpec.describe LocalClusterer do
  let(:article) { create(:article, title: "Mayor charged in bribe case") }

  context "with no recent approved articles" do
    it "creates a fresh slug for the new story" do
      result = described_class.call(article, [])

      expect(result).to eq(
        story_key:     "mayor-charged-in-bribe-case",
        superseded_id: nil,
        supersede:     false,
        duplicate:     false
      )
    end
  end

  context "when a recent article has the same title" do
    let(:recent) { [[12, "mayor-charged", "MAYOR CHARGED IN BRIBE CASE!"]] }

    it "marks the article as a duplicate of the existing story" do
      result = described_class.call(article, recent)

      expect(result).to eq(
        story_key:     "mayor-charged",
        superseded_id: 12,
        supersede:     false,
        duplicate:     true
      )
    end
  end

  context "when recent articles cover other events" do
    let(:recent) { [[5, "unrelated-scandal", "Unrelated scandal elsewhere"]] }

    it "creates a fresh slug and does not flag a duplicate" do
      result = described_class.call(article, recent)

      expect(result).to include(
        story_key: "mayor-charged-in-bribe-case",
        duplicate: false,
        supersede: false
      )
    end
  end

  context "when the title is blank" do
    it "falls back to the article's public_id" do
      article = create(:article, title: nil)

      result = described_class.call(article, [])

      expect(result[:story_key]).to eq(article.public_id)
      expect(result[:duplicate]).to eq(false)
    end
  end
end
