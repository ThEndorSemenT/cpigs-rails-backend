# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_20_192155) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "articles", force: :cascade do |t|
    t.string "author"
    t.text "content"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "external_id", null: false
    t.string "image_url"
    t.string "language", default: "en", null: false
    t.datetime "notified_at"
    t.integer "preview_views", default: 0, null: false
    t.string "public_id", null: false
    t.datetime "published_at"
    t.float "relevance_score"
    t.string "source_name"
    t.string "status", default: "pending", null: false
    t.string "story_key"
    t.string "telegram_channel"
    t.bigint "telegram_message_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["external_id"], name: "index_articles_on_external_id", unique: true
    t.index ["language"], name: "index_articles_on_language"
    t.index ["public_id"], name: "index_articles_on_public_id", unique: true
    t.index ["published_at"], name: "index_articles_on_published_at"
    t.index ["status"], name: "index_articles_on_status"
    t.index ["story_key"], name: "index_articles_on_story_key"
  end

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.bigint "associated_id"
    t.string "associated_type"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.bigint "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "game_results", force: :cascade do |t|
    t.datetime "blockchain_notified_at"
    t.string "blockchain_status", default: "pending", null: false
    t.jsonb "blockchain_tx_data", default: {}
    t.datetime "created_at", null: false
    t.boolean "draw", default: false, null: false
    t.bigint "game_session_id", null: false
    t.bigint "loser_id"
    t.datetime "updated_at", null: false
    t.bigint "winner_id"
    t.index ["blockchain_status"], name: "index_game_results_on_blockchain_status"
    t.index ["game_session_id"], name: "index_game_results_on_game_session_id", unique: true
  end

  create_table "game_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_player_id"
    t.datetime "expires_at"
    t.string "game_type", null: false
    t.boolean "is_vs_cpu", default: false, null: false
    t.string "matchmaking_token", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "player1_id", null: false
    t.bigint "player2_id"
    t.datetime "resolved_at"
    t.string "status", default: "waiting", null: false
    t.datetime "updated_at", null: false
    t.bigint "winner_id"
    t.index ["game_type", "status"], name: "index_game_sessions_on_game_type_and_status"
    t.index ["matchmaking_token"], name: "index_game_sessions_on_matchmaking_token", unique: true
    t.index ["player1_id"], name: "index_game_sessions_on_player1_id"
    t.index ["player2_id"], name: "index_game_sessions_on_player2_id"
    t.index ["status"], name: "index_game_sessions_on_status"
  end

  create_table "moves", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "game_session_id", null: false
    t.string "move_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.bigint "player_id", null: false
    t.integer "sequence", null: false
    t.datetime "updated_at", null: false
    t.index ["game_session_id", "player_id", "move_type"], name: "index_moves_on_game_session_id_and_player_id_and_move_type"
    t.index ["game_session_id", "sequence"], name: "index_moves_on_game_session_id_and_sequence", unique: true
    t.index ["game_session_id"], name: "index_moves_on_game_session_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nonce", null: false
    t.datetime "updated_at", null: false
    t.string "wallet_address", null: false
    t.index ["nonce"], name: "index_players_on_nonce"
    t.index ["wallet_address"], name: "index_players_on_wallet_address", unique: true
  end
end
