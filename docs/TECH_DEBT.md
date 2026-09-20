# Tech Debt

## Security

### ~~SIWE signature verification not implemented~~ ✅ Done
**Files:** `app/channels/application_cable/connection.rb`, `app/controllers/api/v1/auth/sessions_controller.rb`, `app/services/token_service.rb`

Resolved. The full SIWE flow is now implemented:
1. `POST /api/v1/auth/verify` accepts `{ message, signature }`, recovers the wallet via `Eth::Signature.personal_recover`, and verifies it matches the claimed address.
2. Nonce is single-use — `player.regenerate_nonce!` is called after each successful verification.
3. A stateless HMAC-signed bearer token is issued and required on all game endpoints (`Authorization: Bearer <token>`).
4. `ApplicationCable::Connection` verifies the token on WebSocket connect (via `Sec-WebSocket-Protocol` header or `?token=` query param) and rejects unauthenticated connections.
5. `display_name` column dropped from `players` table.

---

### API secrets in environment variables
**Files:** `app/jobs/blockchain/notify_result_job.rb`, `config/settings.yml`

`GAME_RESULT_API_KEY` and `GAME_RESULT_API_URL` are read from env vars as a stop-gap. They should be stored in Rails encrypted credentials (`config/credentials.yml.enc`) so they are never in plaintext on disk or in process env.

**Required work:**
```bash
rails credentials:edit          # requires a TTY — do this manually
# add:
# game:
#   result_api_url: https://...
#   result_api_key: secret
```
Then update `NotifyResultJob` to read `Rails.application.credentials.dig(:game, :result_api_key)`.

---

## Architecture

### Action Cable backed by Redis (Sidekiq's Redis)
Action Cable is currently enabled but has no explicit adapter configured, so it defaults to the async adapter (in-process, single-server only). In production it needs a Redis adapter to work across multiple Puma processes/nodes.

**Required work:** Add to `config/cable.yml`:
```yaml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
  channel_prefix: cpigs_production
```
The same Redis instance used by Sidekiq can be reused.

---

### CPU vs-CPU move resolution is incomplete
**File:** `app/jobs/matchmaking/cpu_fallback_job.rb`

CPU moves are stored in `game_session.metadata["cpu_moves"]` but `Games::SubmitMove` never reads them. When `all_moves_submitted?` is called on a vs-CPU session it only checks `player1`'s moves — the engine's `player2_or_cpu` returns `nil` for vs-CPU games and the score for the CPU side is always 0.

**Required work:** When a session is `is_vs_cpu`, `Games::SubmitMove` (or the engine) should inject the CPU's pre-generated moves from metadata before checking `all_moves_submitted?` and computing scores.

---

### `tokenIdLost` / `tokenIdToAddPower` mapping is a placeholder
**File:** `app/jobs/blockchain/notify_result_job.rb`

Per the upstream docs (`GAME_INTEGRATION_PLAN.md`): _"The exact mapping may be refined once the external API contract is finalised."_ Currently both `tokenIdLost` and `tokenIdCardB` point to the loser's first card, and `tokenIdToAddPower` and `tokenIdCardA` point to the winner's first card. This may not match what the Polygon contract actually expects.

---

### No rate limiting on game endpoints
There is no per-wallet or per-IP rate limiting on matchmaking or move submission. A bad actor could flood the matchmaking queue or replay moves.

**Required work:** Add `rack-attack` and define throttles for `/api/v1/matchmaking` and `/api/v1/game_sessions/:id/moves`.

---

### `blueprinter` gem added but not yet used
The gem is in the Gemfile but no blueprints have been created. Controller `render json:` calls are hand-rolled. Consider extracting serialisers once the API surface stabilises.

---

## Migrations / Schema

### Foreign key constraints missing from game tables
The migrations add indexes but not `foreign_key` constraints for `player1_id`, `player2_id`, `winner_id`, etc. on `game_sessions`, and `player_id`/`game_session_id` on `moves` and `game_results`. Orphaned rows are possible if players or sessions are deleted without going through the model's `dependent:` callbacks.

---

## Testing

### No tests for game code
The `cpigs-backend` source had RSpec specs (factories, model specs, `LogicEngine` spec, `SubmitMove` spec). None have been ported. Before shipping to production, port or rewrite:
- `spec/models/game_session_spec.rb`
- `spec/models/player_spec.rb`
- `spec/games/logic_engine_spec.rb`
- `spec/services/games/submit_move_spec.rb`
- `spec/factories/` (players, game_sessions, moves, game_results)
