lock "~> 3.20.1"

set :application, "cpigs-backend"
set :repo_url, "git@github.com:ThEndorSemenT/cpigs-rails-backend.git"
set :deploy_to, "/var/www/#{fetch(:application)}"
set :branch, ENV.fetch("BRANCH", "main")

set :rbenv_type, :user
set :rbenv_ruby, "3.3.4"

namespace :check do
  desc 'Validate required environment variables'
  task :env_vars do
    on roles(:app) do
      required_vars = %w[
        REDIS_URL
      ]

      # Use stage name for env file (staging.env), not rails_env (production.env)
      env_file = shared_path.join("config/#{fetch(:stage)}.env")

      unless test(:test, '-f', env_file)
        raise "Environment file not found: #{env_file}"
      end

      required_vars.each do |var|
        unless test(:grep, '-Eq', "^#{var}=.+", env_file)
          raise "Missing or empty environment variable: #{var}"
        end
      end

      info "All required environment variables are present"
    end
  end
end

before 'deploy:starting', 'check:env_vars'

# Reserve a different localhost port for each application on this VPS.
# Port 3000 is used by another app, so this one uses 3001.
# The shared Puma config must bind this address; puma_bind alone does not
# configure Puma when systemd starts it (see docs/operations.md).
set :puma_bind, "tcp://127.0.0.1:3001"
set :puma_systemctl_user, :user
# Enable lingering once with sudo on the VPS, not during automated deployments.
set :puma_enable_lingering, false
set :puma_systemd_watchdog_sec, 30
set :puma_phased_restart, true

# Run Rails migrations on the app host.
set :migration_role, :app

set :keep_releases, 3
set :format, :airbrussh

# Linked files are set per-stage since the env file name varies.
# See config/deploy/staging.rb
append :linked_files,
       "config/master.key",
       "config/puma.rb"

namespace :deploy do
  desc 'Upload VPS-specific Puma configuration'
  task :upload_puma_config do
    on roles(:app) do
      upload! 'config/puma.webdock.rb',
              "#{shared_path}/config/puma.rb"
    end
  end
end
before 'deploy:check:linked_files', 'deploy:upload_puma_config'

namespace :deploy do
  desc 'Upload VPS-specific master key'
  task :upload_master_key do
    on roles(:app) do
      upload! 'config/master.key',
              "#{shared_path}/config/master.key"
    end
  end
end
before 'deploy:check:linked_files', 'deploy:upload_master_key'

# Runtime secrets/configuration are provisioned outside release directories.
# Add linked files only after their shared paths and contents are configured.
append :linked_dirs, "log",
       "tmp/pids",
       "tmp/cache",
       "tmp/sockets",
       "storage",
       "public/assets"

set :puma_init_active_record, true
