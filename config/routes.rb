Rails.application.routes.draw do
  # Sidekiq web UI (mount only in development for safety)
  require "sidekiq/web"
  require "sidekiq/cron/web"
  mount Sidekiq::Web => "/sidekiq" if Rails.env.development?

  # Action Cable WebSocket endpoint
  mount ActionCable.server => "/cable"

  # Health check
  get "/up", to: proc { [200, {}, ["OK"]] }

  # Game API
  namespace :api do
    namespace :v1 do
      get  "health",                               to: "health#show"
      post "auth/verify",                          to: "auth/sessions#verify"
      get  "players/:wallet_address/nonce",        to: "players#nonce"
      get  "players/:wallet_address",              to: "players#show"
      post "matchmaking",                          to: "matchmaking#create"
      resources :game_sessions, only: %i[show] do
        post "moves", to: "game_sessions#submit_move", on: :member
      end
    end
  end

  # Article preview pages — the short-URL destination
  # Constraint ensures this never swallows /rails/... or /up
  get "/:public_id", to: "articles#show", as: :article,
    constraints: { public_id: /[a-z0-9]{8}/ }

  # Root redirects to the main corruptedpigs site
  root to: redirect("https://corruptedpigs.com", status: 302)
end
