# Simulation mode ("test mode")

Lets the game run end-to-end **without the Polygon chain**: NFT ownership comes
from a DB table, results are never sent on-chain, and testers can play with any
wallet. The decision is **per request, made by the frontend**; the backend only
obeys if simulation is *allowed* in that environment.

## How the decision flows
```
client signal ──► ApiController ──► Current.simulation ──► GameSession.simulation (persisted)
X-Simulation: on   (signal && Simulation.allowed?)         ▲ source of truth for jobs/services/channels
?simulation=on (cable)                                      │
                                       jobs, SubmitMove, LogicEngine, channels read session.simulation?
```
1. **Permission** – `Simulation.allowed?` (`app/services/simulation.rb`) reads `config.x.simulation_allowed` ← `settings.yml` ← `SIMULATION_ALLOWED`. Default: `true` in development/test, `false` in production. It is the *only* reader of that config. **Future Flipper:** replace the body with `Flipper.enabled?(:simulation)` (`flipper-active_record`, no Redis) — nothing else changes.
2. **Signal** – REST header `X-Simulation: on`; ActionCable handshake `/cable?token=…&simulation=on`. Anything else = real mode.
3. **Resolution** – `ApiController#resolve_simulation!` sets `Current.simulation` once per request (`signal && allowed`). Signal present but not allowed → **403** (never a silent fall back to real).
4. **Persistence** – `game_sessions.simulation` (bool, default false, NOT NULL) is set at matchmaking. Jobs (`NotifyResultJob`, `ResolveSessionJob`, `CpuFallbackJob`) run outside the request and cannot see the header, so they use `session.simulation?`, never config/`Current`.

## Isolation (the main defence — the client controls the mode)
- **Pools**: `GameSession.find_or_create_for_matchmaking(…, simulation:)` filters by `simulation`; simulated and real players never pair. Channels apply the same rule using the connection's `?simulation=` param.
- **Tokens**: `POST /api/v1/auth/simulate {wallet}` (needs the header, else 404; rate-limited 20/min/IP via `rate_limit`, uses `Rails.cache`, no Redis needed) issues a token with claim **`sim: true`** and **no SIWE**, so it proves nothing about wallet ownership. Therefore:
  - a `sim` token on a request without the signal → **401** (REST) / connection rejected (cable);
  - a session is only reachable by a request of the same mode (`GameSessionsController#load_session`, channels) → a `sim` token can never read or move in a real session; real requests cannot see simulated sessions either (404).
  - A real (SIWE) token may be used in a simulated request (harmless: simulated cards, no chain).
- **Residual risk**: `/auth/simulate` creates a `Player` row for any wallet (shared table). Simulated sessions show that wallet address to the opponent. Acceptable for a test mode; keep `SIMULATION_ALLOWED=false` where this is not wanted.

## What changes for a simulated request/session
- `GET /api/v1/players/:wallet/cards` → cards from `simulated_nfts` (404 without signal, 403 if not allowed).
- `LogicEngine` select_cards: cards must belong to the wallet, be `available`, distinct, with the stored `burn_power` (`Simulation::CardOwnership`). Real sessions keep trusting the client as before.
- `SubmitMove` resolves **inline** and the move response includes `result: {draw, winner_wallet, loser_wallet}`.
- `NotifyResultJob` marks `skipped` before Faraday (even if simulation was disabled afterwards — the session decides).
- `POST /api/v1/rpc/polygon` → 403. `Simulation::Guard.ensure_chain_allowed!(session_or_bool)` raises `Simulation::BlockedError`; call it before any new chain code.
- Matchmaking/session JSON include `simulation`.

## Flags
| Env | Default | Meaning |
|---|---|---|
| `SIMULATION_ALLOWED` | dev/test `true`, production `false` | Whether clients may request simulation. |
| `SIMULATION_COLLECTION` | `cpigs-collection-879234287` | Default catalog = `config/simulation/collections/<name>.yml` (OpenSea slug). |

Set `SIMULATION_ALLOWED` on both web and Sidekiq (see `docker-compose.yml`). The reverse proxy must forward `X-Simulation` and the `/cable` query string. CORS uses `headers: :any`, so `X-Simulation` is already accepted.

## Catalog file
`config/simulation/collections/<name>.yml` is the pool of tokens `Simulation::AssignCards` can hand out (`token_id, name, image, burn_power`); it picks random entries the wallet does not own yet, so its size is the **maximum distinct cards per wallet**. The 30 entries are placeholders — replace with the real collection. No chain calls ever read it.

## Seeding cards
```bash
bin/rails "simulation:assign[0xWALLET,10]"          # idempotent, never repeats tokens
bin/rails "simulation:assign[0xWALLET,10,other]"    # explicit collection
bin/rails "simulation:list[0xWALLET]"
bin/rails "simulation:reset[0xWALLET]"
```
Refuses in production unless `SIMULATION_ALLOWED=true`.

## Bot player (designed, NOT implemented)
Goal: "Player vs Computer" without the broken `cpu_card_N` path (see `docs/TECH_DEBT.md`).
1. The bot is a normal `Player` whose wallet comes from `BOT_WALLET_ADDRESS` (ENV); `Player.find_or_create_by_wallet`.
2. `Matchmaking::CpuFallbackJob` reads **`session.simulation?`** (not config/`Current`). For simulated sessions: ensure the bot has ≥ 3 `available` cards via `Simulation::AssignCards.call(wallet: ENV["BOT_WALLET_ADDRESS"], count: N)`, then `add_second_player!(bot)` and submit its `select_cards` / `guess_card` through `Games::SubmitMove` (shared ownership validation and inline resolution).
3. Then remove the `is_vs_cpu` special-casing in `LogicEngine` (`player2_or_cpu`, `cpu_moves`, `generate_cpu_cards`).
4. No transactions or COINK in simulation.
Open question: should the bot's `guess_card` be smart (highest `burn_power`, as `cpu_moves` does today) or random?

## Not done yet
Card status transitions (`locked`/`lost`) after a game; real catalog data; rate limiting beyond `/auth/simulate`.
