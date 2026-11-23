# Simulation mode

Lets the game run end-to-end **without the Polygon chain**: NFT ownership comes
from a DB table, results are never sent on-chain, and a single backend can be
played by testers with arbitrary wallets.

## Flags
| Env | Default | Meaning |
|---|---|---|
| `SIMULATION_MODE` | `false` | Master switch (`Simulation.enabled?`). Everything below is gated by it; real mode is untouched. |
| `SIMULATION_COLLECTION` | `cpigs-collection-879234287` | Catalog name = file in `config/simulation/collections/<name>.yml` (name is the OpenSea collection slug). |

Read in `config/settings.yml` → `config/initializers/simulation.rb` →
`Rails.application.config.x.simulation_mode / simulation_collection`.
**Set it on both the web and the Sidekiq worker** (see `docker-compose.yml`).

## What changes when on
- `simulated_nfts` (`wallet_address` lowercase, `collection`, `token_id`, `burn_power`, `status` available/locked/lost; unique on wallet+collection+token) replaces on-chain ownership.
- `GET /api/v1/players/:wallet/cards` and `POST /api/v1/auth/simulate {wallet}` (token without SIWE) exist; both are **404 when off**.
- `Games::LogicEngine` select_cards: cards must belong to the wallet, be `available`, distinct, with the stored `burn_power` (the client value is no longer trusted).
- `Games::SubmitMove` resolves **inline** and the move response includes `result: {draw, winner_wallet, loser_wallet}`.
- `Blockchain::NotifyResultJob` marks the result `skipped` and returns before Faraday.
- `POST /api/v1/rpc/polygon` → 403. `Simulation::Guard.ensure_chain_allowed!` raises `Simulation::BlockedError`; call it before any new chain code.

## Catalog file
`config/simulation/collections/<name>.yml` is the pool of tokens that can be
handed out (`token_id, name, image, burn_power`). `Simulation::AssignCards`
picks random entries from it that the wallet does not own yet, so the catalog
size is the **maximum number of distinct cards per wallet**. The current 30
entries are placeholders; replace with the real collection (the game needs ≥ 3
per player, 30 just gives variety). No chain calls ever read it.

## Seeding cards
```bash
bin/rails "simulation:assign[0xWALLET,10]"          # idempotent, never repeats tokens
bin/rails "simulation:assign[0xWALLET,10,other]"    # explicit collection
bin/rails "simulation:list[0xWALLET]"
bin/rails "simulation:reset[0xWALLET]"
```
Refuses in production unless `SIMULATION_MODE=true`.

## Bot player (designed, NOT implemented)
Goal: "Player vs Computer" without the broken `cpu_card_N` path (see
`docs/TECH_DEBT.md`).
1. The bot is a normal `Player` whose wallet comes from `BOT_WALLET_ADDRESS` (ENV, no hardcoding); `Player.find_or_create_by_wallet`.
2. Give it cards with `Simulation::AssignCards.call(wallet: ENV["BOT_WALLET_ADDRESS"], count: N)` (same table/service). Top it up when fewer than 3 `available` cards remain.
3. In `Matchmaking::CpuFallbackJob`: instead of `fall_back_to_cpu!` + metadata moves, `add_second_player!(bot)`, then submit the bot's `select_cards` (3 `available` cards) and `guess_card` through `Games::SubmitMove`, so ownership validation and resolution are shared with human games.
4. Then remove `is_vs_cpu` special-casing in `LogicEngine` (`player2_or_cpu`, `cpu_moves`, `generate_cpu_cards`).
5. No transactions or COINK are needed in simulation.
Open question: should the bot's `guess_card` be smart (highest burn_power, as `cpu_moves` does today) or random?

## Not done yet
Card status transitions (`locked`/`lost`) after a game; real catalog data.
