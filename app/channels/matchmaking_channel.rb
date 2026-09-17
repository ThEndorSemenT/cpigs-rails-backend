# Subscribe: { channel: "MatchmakingChannel", token: "<matchmaking_token>" }
# Broadcasts: "matched" { vs_cpu: bool, session_id: int }
class MatchmakingChannel < ApplicationCable::Channel
  def subscribed
    session = GameSession.find_by(matchmaking_token: params[:token])
    return reject unless session

    stream_from "matchmaking_#{params[:token]}"

    # Handle reconnect: immediately transmit if already matched
    if session.status != "waiting"
      transmit({ type: "matched", vs_cpu: session.is_vs_cpu, session_id: session.id })
    end
  end

  def unsubscribed = stop_all_streams
end
