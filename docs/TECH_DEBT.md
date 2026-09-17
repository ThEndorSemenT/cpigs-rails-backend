# Tech Debt

## Security

### SIWE signature verification not implemented
**Files:** `app/channels/application_cable/connection.rb`, `app/controllers/api/v1/players_controller.rb`

The SIWE (Sign-In with Ethereum) nonce flow is wired up (nonce issued, regenerated after use) but the signature is never verified. Currently any request with an `X-Wallet-Address` header is trusted at face value. This means **any client can impersonate any wallet address**.

**Required work:**
1. Add a `POST /api/v1/players/:wallet_address/verify` endpoint that accepts `{ signature: "0x..." }`.
2. Reconstruct the EIP-4361 message server-side and call `eth_recover` (or use the `siwe` gem) to confirm the signature matches the wallet address.
3. Issue a short-lived session token (JWT or encrypted cookie) on success.
4. Require that token (not just the header) for all game actions.
5. Regenerate the nonce after successful verification so it cannot be replayed.

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
