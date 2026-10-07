# Deterministic, offline story clustering used when the AI filter is
# unavailable (no API key configured, or the API rejected our key).
#
# Returns the same result shape as AiFilter#cluster:
#   { story_key:, superseded_id:, supersede:, duplicate: }
#
# Without an LLM we can only detect exact (normalised) title matches, so
# `supersede` is never true here — articles with a title identical to a
# recently approved one are dropped as duplicates, everything else gets a
# fresh slug.
class LocalClusterer
  def self.call(article, recent_articles)
    new(article, recent_articles).call
  end

  # recent_articles: array of [id, story_key, title] tuples (see ArticleFilterJob)
  def initialize(article, recent_articles)
    @article         = article
    @recent_articles = recent_articles
  end

  def call
    match = find_match

    if match
      { story_key: match[:story_key], superseded_id: match[:id],
        supersede: false, duplicate: true }
    else
      { story_key: slugify(@article.title).presence || @article.public_id,
        superseded_id: nil, supersede: false, duplicate: false }
    end
  end

  private

  def find_match
    normalized = normalize(@article.title)
    return nil if normalized.blank?

    @recent_articles.each do |id, story_key, title|
      return { id: id, story_key: story_key } if normalize(title) == normalized
    end

    nil
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  def slugify(text)
    text.to_s
        .downcase
        .gsub(/[^a-z0-9\s-]/, "")
        .gsub(/\s+/, "-")
        .slice(0, 60)
        .sub(/-+$/, "")
  end
end
