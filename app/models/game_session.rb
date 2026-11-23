class GameSession < ApplicationRecord
  include HasPublicId
  STATUSES = %w[waiting active playing resolving resolved expired cancelled].freeze
  # waiting   – P1 joined, waiting for P2 or CPU fallback timer
  # active    – both players connected
  # playing   – moves being submitted
  # resolving – all moves received, engine determining winner
  # resolved  – winner determined
  # expired   – matchmaking window closed with no P2, or move deadline missed
  # cancelled – aborted

  # Source of truth for the matchmaking window. Exposed to clients via
  # `expires_at` / `server_time` / `matchmaking_timeout_seconds` — never duplicate it in the frontend.
  MATCHMAKING_TIMEOUT_SECONDS = 30
  # Time both players have to finish their moves once the session is active.
  # Exposed to clients as `move_deadline_at`. TODO(product): confirm 60s.
  MOVE_TIMEOUT_SECONDS = 60

  belongs_to :player1,        class_name: "Player"
  belongs_to :player2,        class_name: "Player", optional: true
  belongs_to :current_player, class_name: "Player", optional: true
  belongs_to :winner,         class_name: "Player", optional: true
  has_many   :moves,          dependent: :destroy
  has_one    :game_result,    dependent: :destroy

  # Reason the session was closed; stored in metadata["expired_reason"].
  attr_accessor :expire_reason

  validates :game_type,         presence: true, inclusion: { in: -> (_) { Games::Registry.game_types } }
  validates :status,            presence: true, inclusion: { in: STATUSES }
  validates :matchmaking_token, presence: true, uniqueness: true

  before_validation :set_defaults, on: :create
  after_commit :flush_pending_events
  after_rollback :clear_pending_events

  scope :waiting,           -> { where(status: "waiting") }
  scope :active,            -> { where(status: %w[active playing]) }
  scope :for_game_type,     ->(type) { where(game_type: type) }
  # Waiting sessions whose matchmaking window has closed (expires_at is the source of truth).
  scope :stale_matchmaking, -> { waiting.where("expires_at <= ?", Time.current) }
  # Sessions still accepting moves whose deadline has passed.
  scope :overdue_moves,     -> { active.where("move_deadline_at <= ?", Time.current) }

  # Find open session for this game_type or create a new one.
  # - A player has at most one waiting session per game_type/simulation: stale ones are
  #   expired, a still-valid one is returned as-is (idempotent re-join).
  # - Matching only considers non-expired sessions, oldest first, with
  #   SELECT FOR UPDATE SKIP LOCKED to avoid race conditions.
  # - Simulated and real players never share a pool.
  def self.find_or_create_for_matchmaking(player:, game_type:, simulation: false)
    transaction do
      # Serialise concurrent joins of the same player.
      Player.lock.find(player.id)
      now = Time.current

      own = waiting.for_game_type(game_type).where(simulation: simulation, player1_id: player.id)
                   .order(:created_at, :id).lock.to_a
      valid, stale = own.partition { |s| s.expires_at.present? && s.expires_at > now }
      stale.each { |s| s.expire!(reason: "timeout") }
      valid.drop(1).each { |s| s.expire!(reason: "superseded") }
      next valid.first if valid.first

      open_session = waiting
        .for_game_type(game_type)
        .where(simulation: simulation)
        .where.not(player1_id: player.id)
        .where("expires_at > ?", now)
        .order(:created_at, :id)
        .lock("FOR UPDATE SKIP LOCKED")
        .first

      if open_session
        open_session.add_second_player!(player)
        open_session
      else
        create!(
          game_type:  game_type,
          player1:    player,
          simulation: simulation,
          status:     "waiting",
          expires_at: MATCHMAKING_TIMEOUT_SECONDS.seconds.from_now
        )
      end
    end
  end

  # Human opponent joined. Notifies P1 over Action Cable once the transaction commits.
  def add_second_player!(player)
    update!(player2: player, status: "active", is_vs_cpu: false,
            move_deadline_at: MOVE_TIMEOUT_SECONDS.seconds.from_now)
    queue_event(:matched)
    queue_event(:schedule_move_deadline)
  end

  def fall_back_to_cpu!
    update!(status: "active", is_vs_cpu: true,
            move_deadline_at: MOVE_TIMEOUT_SECONDS.seconds.from_now)
    queue_event(:matched)
    queue_event(:schedule_move_deadline)
  end

  def start_playing!;    update!(status: "playing")   end
  def begin_resolution!; update!(status: "resolving") end

  # Idempotent and safe under concurrency: only transitions from one of `from`
  # (row-locked), broadcasts `expired` once after commit. Returns true if it transitioned.
  def expire!(reason: "timeout", from: %w[waiting])
    expired = with_lock do
      next false unless from.include?(status)

      self.expire_reason = reason
      update!(status: "expired", metadata: (metadata || {}).merge("expired_reason" => reason))
      queue_event(:expired)
      true
    end
    expired
  end

  # Payloads shared by HTTP responses and Action Cable (see docs/MATCHMAKING.md).
  def timing_json
    {
      expires_at:                  expires_at&.iso8601(3),
      move_deadline_at:            move_deadline_at&.iso8601(3),
      server_time:                 Time.current.iso8601(3),
      matchmaking_timeout_seconds: MATCHMAKING_TIMEOUT_SECONDS,
      move_timeout_seconds:        MOVE_TIMEOUT_SECONDS
    }
  end

  def matched_payload
    {
      type:             "matched",
      vs_cpu:           is_vs_cpu,
      session_id:       to_param,
      public_id:        public_id,
      move_deadline_at: move_deadline_at&.iso8601(3),
      server_time:      Time.current.iso8601(3)
    }
  end

  def expired_payload
    { type: "expired", reason: expire_reason || metadata&.dig("expired_reason") || status }
  end

  def resolve!(winner_player: nil, draw: false)
    transaction do
      self.winner      = winner_player unless draw
      self.status      = "resolved"
      self.resolved_at = Time.current
      save!
    end
  end

  def opponent_for(player)
    return nil if is_vs_cpu && player == player1
    player == player1 ? player2 : player1
  end

  def participants; [player1, player2].compact end

  def engine
    Games::Registry.engine_for(game_type).new(self)
  end

  def move_for(player, move_type)
    moves.find_by(player_id: player.id, move_type: move_type)
  end

  def all_moves_submitted?
    engine.all_moves_submitted?
  end

  private

  def queue_event(event)
    (@pending_events ||= []) << event
  end

  def clear_pending_events
    @pending_events = nil
  end

  # Side effects run after the transaction commits, so clients never see state that
  # could still roll back. Broadcast failures (e.g. Redis down) must not fail the request.
  def flush_pending_events
    events = @pending_events
    @pending_events = nil
    Array(events).uniq.each do |event|
      case event
      when :matched
        ActionCable.server.broadcast("matchmaking_#{matchmaking_token}", matched_payload)
      when :expired
        ActionCable.server.broadcast("matchmaking_#{matchmaking_token}", expired_payload)
        ActionCable.server.broadcast("game_session_#{id}", expired_payload)
      when :schedule_move_deadline
        Games::MoveDeadlineJob.set(wait_until: move_deadline_at).perform_later(id)
      end
    rescue StandardError => e
      Rails.logger.error("[GameSession##{id}] #{event} side effect failed: #{e.class}: #{e.message}")
    end
  end

  def set_defaults
    self.status            ||= "waiting"
    self.matchmaking_token ||= SecureRandom.urlsafe_base64(16)
    self.metadata          ||= {}
  end
end
