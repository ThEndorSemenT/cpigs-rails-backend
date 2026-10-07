FactoryBot.define do
  factory :article do
    sequence(:external_id) { |n| "newsapi-article-#{n}" }
    title        { "Minister arrested in bribery probe" }
    description  { "Federal police detained the minister on kickback charges." }
    content      { "Full story about the kickback scheme uncovered by auditors." }
    url          { "https://example.com/news/minister-arrested" }
    source_name  { "Example Wire" }
    language     { "en" }
    status       { "pending" }
    published_at { 1.hour.ago }
  end
end
