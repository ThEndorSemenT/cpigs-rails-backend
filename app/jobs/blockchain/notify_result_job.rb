# Posts game result to external Polygon API.
# Retries up to 5× with exponential back-off.
# URL and API key are read from config/settings.yml (game.result_api_url / game.result_api_key).
# Fall back to env vars GAME_RESULT_API_URL / GAME_RESULT_API_KEY if settings not present.
module Blockchain
  class NotifyResultJob < ApplicationJob
    queue_as :blockchain
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(game_result_id)
      result = GameResult.includes(:winner, :loser, game_session: :moves).find_by(id: game_result_id)
      return unless result
      return if result.blockchain_status == "notified"

      settings = Rails.application.config_for(:settings) rescue {}
      api_url  = settings.dig("game", "result_api_url") || ENV.fetch("GAME_RESULT_API_URL", nil)
      api_key  = settings.dig("game", "result_api_key") || ENV.fetch("GAME_RESULT_API_KEY", nil)

      unless api_url.present? && api_key.present?
        Rails.logger.warn("[Blockchain::NotifyResultJob] Missing API URL/key — skipping blockchain notification")
        result.skip_blockchain!
        return
      end

      conn = Faraday.new do |f|
        f.request :json
        f.request :retry, max: 2, interval: 1, backoff_factor: 2
        f.response :raise_error
      end

      response = conn.post(api_url, build_payload(result, api_key))
      result.mark_notified!(response_body: response.body, status: response.status)
    rescue Faraday::Error => e
      result.mark_failed!(error: e.message, class: e.class.name)
      raise  # re-raise so Sidekiq retries
    end

    private

    def build_payload(result, api_key)
      session      = result.game_session
      winner_cards = cards_for(session, result.winner)
      loser_cards  = cards_for(session, result.loser)
      {
        apiKey:            api_key,
        winner:            result.winner&.wallet_address,
        loser:             result.loser&.wallet_address,
        tokenIdCardA:      winner_cards.first&.dig("token_id"),
        tokenIdCardB:      loser_cards.first&.dig("token_id"),
        tokenIdLost:       loser_cards.first&.dig("token_id"),
        tokenIdToAddPower: winner_cards.first&.dig("token_id"),
        draw:              result.draw,
        gameType:          session.game_type,
        sessionId:         session.id.to_s
      }
    end

    def cards_for(session, player)
      return [] unless player
      move = session.moves.find_by(player_id: player.id, move_type: "select_cards")
      move&.payload&.dig("cards") || []
    end
  end
end
