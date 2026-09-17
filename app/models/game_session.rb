class GameSession < ApplicationRecord
  STATUSES = %w[waiting active playing resolving resolved expired cancelled].freeze
  # waiting   – P1 joined, waiting for P2 or CPU fallback timer
  # active    – both players connected
  # playing   – moves being submitted
  # resolving – all moves received, engine determining winner
  # resolved  – winner determined
  # expired   – matchmaking window closed with no P2
  # cancelled – aborted

  MATCHMAKING_TIMEOUT_SECONDS = 30

  belongs_to :player1,        class_name: "Player"
  belongs_to :player2,        class_name: "Player", optional: true
  belongs_to :current_player, class_name: "Player", optional: true
  belongs_to :winner,         class_name: "Player", optional: true
  has_many   :moves,          dependent: :destroy
  has_one    :game_result,    dependent: :destroy

  validates :game_type,         presence: true, inclusion: { in: -> (_) { Games::Registry.game_types } }
  validates :status,            presence: true, inclusion: { in: STATUSES }
  validates :matchmaking_token, presence: true, uniqueness: true

  before_validation :set_defaults, on: :create

  scope :waiting,           -> { where(status: "waiting") }
  scope :active,            -> { where(status: %w[active playing]) }
  scope :for_game_type,     ->(type) { where(game_type: type) }
  scope :stale_matchmaking, -> { waiting.where("created_at < ?", MATCHMAKING_TIMEOUT_SECONDS.seconds.ago) }

  # Find open session for this game_type or create a new one.
  # Uses SELECT FOR UPDATE SKIP LOCKED to avoid race conditions.
  def self.find_or_create_for_matchmaking(player:, game_type:)
    transaction do
      open_session = waiting
        .for_game_type(game_type)
        .where.not(player1_id: player.id)
        .lock("FOR UPDATE SKIP LOCKED")
        .first

      if open_session
        open_session.add_second_player!(player)
        open_session
      else
        create!(
          game_type:  game_type,
          player1:    player,
          status:     "waiting",
          expires_at: MATCHMAKING_TIMEOUT_SECONDS.seconds.from_now
        )
      end
    end
  end

  def add_second_player!(player)
    update!(player2: player, status: "active", is_vs_cpu: false)
  end

  def fall_back_to_cpu!
    update!(status: "active", is_vs_cpu: true)
  end

  def start_playing!;    update!(status: "playing")   end
  def begin_resolution!; update!(status: "resolving") end
  def expire!;           update!(status: "expired")   end

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

  def set_defaults
    self.status            ||= "waiting"
    self.matchmaking_token ||= SecureRandom.urlsafe_base64(16)
    self.metadata          ||= {}
  end
end
