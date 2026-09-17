# Subscribe: { channel: "GameSessionChannel", session_id: 42 }
# Broadcasts:
#   "player_joined"    – second player connected
#   "move_received"    – move submitted (no payload to keep opponent cards hidden)
#   "game_resolved"    – winner/loser/draw announced
#   "opponent_timeout" – opponent abandoned
class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    session = GameSession.find_by(id: params[:session_id])
    return reject if session.nil? || !participant?(session)

    stream_from "game_session_#{session.id}"
    transmit({ type: "session_state", session: session_state(session) })
  end

  def unsubscribed = stop_all_streams

  private

  def participant?(session)
    return true unless current_player  # unauthenticated in dev
    session.player1_id == current_player.id || session.player2_id == current_player.id
  end

  def session_state(session)
    { id: session.id, game_type: session.game_type, status: session.status,
      is_vs_cpu: session.is_vs_cpu, player1: session.player1.wallet_address,
      player2: session.player2&.wallet_address }
  end
end
