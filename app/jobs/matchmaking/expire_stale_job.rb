# Sweeper (sidekiq-cron, every minute — config/schedule.yml). Safety net for
# CpuFallbackJob: closes any waiting session past `expires_at`, and any active
# session past `move_deadline_at`. Idempotent; safe to run in duplicate.
module Matchmaking
  class ExpireStaleJob < ApplicationJob
    queue_as :matchmaking

    def perform
      GameSession.stale_matchmaking.find_each do |session|
        Matchmaking::HandleTimeout.new(session).call
      rescue StandardError => e
        Rails.logger.error("[ExpireStaleJob] session #{session.id}: #{e.class}: #{e.message}")
      end

      GameSession.overdue_moves.find_each do |session|
        session.expire!(reason: "move_timeout", from: %w[active playing])
      rescue StandardError => e
        Rails.logger.error("[ExpireStaleJob] session #{session.id}: #{e.class}: #{e.message}")
      end
    end
  end
end
