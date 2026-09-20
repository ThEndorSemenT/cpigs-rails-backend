source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Background jobs
gem "sidekiq", "~> 7.0"
gem "sidekiq-cron", "~> 1.12"
# connection_pool 3.0 changed pop() to keyword args; sidekiq 7.x still uses positional
gem "connection_pool", "~> 2.4"

# Audit trail on Article model
gem "audited", "~> 5.0"

# HTTP client (NewsAPI + Telegram + blockchain notifications)
gem "faraday", "~> 2.0"
gem "faraday-retry", "~> 2.0"

# Game API
gem "rack-cors"
gem "blueprinter"

# Ethereum / SIWE — wallet signature verification
gem "eth", "~> 0.5"

# AI relevance filtering
gem "ruby-openai", "~> 7.0"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-byebug"
  gem "pry-rails"
end

group :development do
  gem "web-console"
end
