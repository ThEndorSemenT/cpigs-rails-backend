# Subscribe: { channel: "MatchmakingChannel", token: "<matchmaking_token>" }
# Broadcasts (see docs/MATCHMAKING.md):
#   matched { vs_cpu, session_id, public_id, move_deadline_at, server_time }
#   expired { reason }
class MatchmakingChannel < ApplicationCable::Channel
  def subscribed
    session = GameSession.find_by(matchmaking_token: params[:token])
    return reject unless session && session_mode_matches?(session)

    stream_from "matchmaking_#{params[:token]}"

    # Handle reconnect: replay the current state if no longer waiting
    case session.status
    when "waiting"
      nil
    when "expired", "cancelled"
      transmit(session.expired_payload)
    else
      transmit(session.matched_payload)
    end
  end

  def unsubscribed = stop_all_streams
end
