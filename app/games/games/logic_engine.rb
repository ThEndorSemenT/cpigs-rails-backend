# "Logic" game — 2-step: select_cards → guess_card
#
# select_cards: { cards: [{ token_id: String, burn_power: Integer }, ...] }  (3 items)
# guess_card:   { index: Integer }  (0, 1, or 2)
#
# Winner: player whose guess lands on the opponent card with higher burn_power
module Games
  class LogicEngine < BaseEngine
    MOVE_SELECT_CARDS   = "select_cards"
    MOVE_GUESS_CARD     = "guess_card"
    REQUIRED_CARD_COUNT = 3

    def valid_move?(player, move_type, payload)
      case move_type
      when MOVE_SELECT_CARDS then valid_select_cards?(payload)
      when MOVE_GUESS_CARD   then valid_guess_card?(payload)
      else false
      end
    end

    def all_moves_submitted?
      active_players.all? do |player|
        move_payload(player, MOVE_SELECT_CARDS).present? &&
          move_payload(player, MOVE_GUESS_CARD).present?
      end
    end

    def resolve!
      p1_score = score_for(player1, player2_or_cpu)
      p2_score = score_for(player2_or_cpu, player1)
      if    p1_score > p2_score then { winner: player1,        loser: player2_or_cpu, draw: false }
      elsif p2_score > p1_score then { winner: player2_or_cpu, loser: player1,        draw: false }
      else                           { winner: nil,            loser: nil,            draw: true  }
      end
    end

    def cpu_moves
      cards = generate_cpu_cards
      highest_index = cards.each_with_index.max_by { |c, _| c[:burn_power] }.last
      [
        { move_type: MOVE_SELECT_CARDS, payload: { cards: cards } },
        { move_type: MOVE_GUESS_CARD,   payload: { index: highest_index } }
      ]
    end

    private

    def score_for(guesser, opponent)
      guess_payload  = move_payload(guesser, MOVE_GUESS_CARD)
      opponent_cards = move_payload(opponent, MOVE_SELECT_CARDS)
      return 0 unless guess_payload && opponent_cards
      guessed_index = guess_payload["index"].to_i
      card = opponent_cards["cards"][guessed_index]
      card ? card["burn_power"].to_i : 0
    end

    def active_players;  [player1, player2_or_cpu].compact end
    def player2_or_cpu;  session.is_vs_cpu ? nil : player2 end

    def valid_select_cards?(payload)
      cards = payload.try(:[], "cards") || payload.try(:[], :cards)
      return false unless cards.is_a?(Array) && cards.size == REQUIRED_CARD_COUNT
      cards.all? do |card|
        card.is_a?(Hash) && card.key?("token_id") &&
          card["burn_power"].is_a?(Integer) && card["burn_power"] >= 0
      end
    end

    def valid_guess_card?(payload)
      index = payload.try(:[], "index") || payload.try(:[], :index)
      index.is_a?(Integer) && index.between?(0, REQUIRED_CARD_COUNT - 1)
    end

    def generate_cpu_cards
      REQUIRED_CARD_COUNT.times.map { |i| { token_id: "cpu_card_#{i}", burn_power: rand(1..15) } }
    end
  end
end

Games::Registry.register("logic", Games::LogicEngine)
