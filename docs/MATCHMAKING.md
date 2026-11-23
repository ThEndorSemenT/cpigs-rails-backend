# Matchmaking contract

The server is the single source of truth for every timer. The frontend derives its
countdowns from the fields below and must not hardcode 30s / 60s.

## HTTP

`POST /api/v1/matchmaking` and `GET /api/v1/game_sessions/:id` include:

| field | meaning |
|---|---|
| `expires_at` | ISO8601 — end of the matchmaking window (`GameSession::MATCHMAKING_TIMEOUT_SECONDS`, 30) |
| `move_deadline_at` | ISO8601 or `null` — set when the session becomes `active` (`MOVE_TIMEOUT_SECONDS`, 60) |
| `server_time` | ISO8601 — use `expires_at - server_time` to avoid client clock skew |
| `matchmaking_timeout_seconds` / `move_timeout_seconds` | the configured durations |

`POST /matchmaking` is idempotent per player/game_type/mode: re-joining while a valid
`waiting` session exists returns that session (no second one). Stale `waiting`
sessions of the player are expired first.

## Action Cable — stream `matchmaking_<token>` (`MatchmakingChannel`, `params: {token}`)

- `matched` `{type, vs_cpu, session_id, public_id, move_deadline_at, server_time}` —
  sent to **P1** when P2 joins (broadcast after commit) or on CPU fallback.
- `expired` `{type, reason}` — `reason`: `timeout`, `superseded`, `move_timeout`, `cancelled`.

On (re)subscribe the channel replays the current state: `matched` if the session is
past `waiting`, `expired` if `expired`/`cancelled`. P2 gets `matched` in the HTTP response.
A move-deadline expiry is also broadcast on `game_session_<id>`.

## Matching rules

Candidates: `status = waiting`, same `game_type` and `simulation`, other player,
`expires_at > now`, `ORDER BY created_at`, `FOR UPDATE SKIP LOCKED`. Expired sessions
are never matched. Simulation and real pools never mix.

## Expiry (two idempotent mechanisms)

1. `Matchmaking::CpuFallbackJob` — scheduled for `expires_at` on session creation.
2. `Matchmaking::ExpireStaleJob` — sidekiq-cron every minute (`config/schedule.yml`);
   handles `waiting` past `expires_at` and `active/playing` past `move_deadline_at`.

Both call `Matchmaking::HandleTimeout`: CPU fallback by default; with
`MATCHMAKING_CPU_FALLBACK=false` the session is expired and `expired` is broadcast.
Row-locked + status recheck, so duplicates are no-ops.

## Move deadline

`Games::MoveDeadlineJob` runs at `move_deadline_at`; if moves are pending the session
becomes `expired` (reason `move_timeout`). `Games::SubmitMove` rejects moves after
the deadline (`"Move deadline passed"`) and expires the session. TODO(product): confirm
60s and whether late = forfeit for the late player only.

## Sidekiq

`config/sidekiq.yml` must list every queue: `default`, `matchmaking`, `game_resolution`,
`blockchain`. Jobs on an unlisted queue are enqueued but never run.
