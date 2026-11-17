# frozen_string_literal: true

# Production Puma configuration for VPS deployment via Capistrano.
# This file is uploaded to shared/config/puma.rb during deployment.

# Application directory
app_dir = File.expand_path("../..", __dir__)
directory app_dir

# Set environment
environment ENV.fetch("RAILS_ENV", "production")

# Bind to localhost on port 3001 (port 3000 is used by another app on this VPS).
# Nginx reverse proxy forwards external requests to this address.
bind "tcp://127.0.0.1:3001"

# Workers and threads
workers ENV.fetch("WEB_CONCURRENCY", 2)
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Preload app for faster worker spawning and copy-on-write memory savings
preload_app!

# PID and state files
pidfile "#{app_dir}/tmp/pids/puma.pid"
state_path "#{app_dir}/tmp/pids/puma.state"

# Logging
stdout_redirect "#{app_dir}/log/puma_access.log", "#{app_dir}/log/puma_error.log", true

# Allow puma to be restarted by systemd watchdog
plugin :tmp_restart

# Reconnect to database after forking
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
