# Deployment Guide

This document covers deploying cpigs-backend to a VPS using Capistrano.

## Prerequisites

### On Your Local Machine
- Ruby 3.3.4 (matching `.ruby-version`)
- Bundler with Capistrano gems installed
- SSH access to the VPS configured in `~/.ssh/config`:
  ```
  Host ubq
    HostName <your-vps-ip>
    User deploy
    IdentityFile ~/.ssh/your_key
  ```

### On the VPS (Webdock or similar)

#### 1. Create deploy user
```bash
sudo adduser deploy
sudo usermod -aG sudo deploy
```

#### 2. Install rbenv and Ruby
```bash
# As deploy user
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 3.3.4
rbenv global 3.3.4
```

#### 3. Install PostgreSQL
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib libpq-dev

# Create database user (answer 'n' to all prompts - no superuser, no createdb, no createrole)
sudo -u postgres createuser --interactive cpigs_news_bot

# Create database
sudo -u postgres createdb -O cpigs_news_bot cpigs_news_bot

# Set password securely (interactive prompt, not saved in bash history)
sudo -u postgres psql
\password cpigs_news_bot
# Enter password when prompted, then:
\q
```

#### 4. Install Redis
```bash
sudo apt install redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

#### 5. Install Nginx
```bash
sudo apt install nginx
```

#### 6. Enable systemd lingering for deploy user
This allows user services (Puma, Sidekiq) to run without an active session:
```bash
sudo loginctl enable-linger deploy
```

#### 7. Create deployment directories
```bash
sudo mkdir -p /var/www/cpigs-backend
sudo chown deploy:deploy /var/www/cpigs-backend
```

## Configuration Files

### Shared Config Directory
Before first deploy, create the shared config directory and files on the VPS:

```bash
mkdir -p /var/www/cpigs-backend/shared/config
```

#### staging.env
Create `/var/www/cpigs-backend/shared/config/staging.env`:
```bash
# Note: RAILS_ENV=production because we don't have a staging environment file
# The "staging" in the filename refers to the Capistrano stage, not Rails env
RAILS_ENV=production
REDIS_URL=redis://localhost:6379/0
OPENAI_API_KEY=your_openai_key_here
CPIGS_NEWS_BOT_DATABASE_PASSWORD=your_db_password_here
```

#### master.key
Copy `config/master.key` from your local machine to the VPS:
```bash
scp config/master.key ubq:/var/www/cpigs-backend/shared/config/
```

**Important:** The `master.key` file is required to decrypt Rails credentials. Never commit it to git.

## Nginx Configuration

After the first deploy, install the nginx config from the deployed release:
```bash
sudo cp /var/www/cpigs-backend/current/config/staging/nginx.conf /etc/nginx/sites-available/cpigs-backend
sudo ln -s /etc/nginx/sites-available/cpigs-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

The config file is at `config/staging/nginx.conf` in the repository.

## TLS with Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d cpigs.to
```

## Deploying

### First Deploy
```bash
# From your local machine
bundle exec cap staging deploy
```

### Subsequent Deploys
```bash
bundle exec cap staging deploy
```

### Useful Commands
```bash
# Check deployment status
cap staging puma:status

# Restart Puma
cap staging puma:restart

# View logs
ssh ubq "tail -f /var/www/cpigs-backend/current/log/production.log"

# Rails console on server
ssh ubq "cd /var/www/cpigs-backend/current && bundle exec rails console -e production"
```

## Sidekiq Worker

The Sidekiq worker runs as a systemd user service, mirroring the Puma unit. The
unit file is installed manually on the VPS (not managed by Capistrano):

```bash
# On the VPS as deploy user
cat > ~/.config/systemd/user/cpigs-backend_sidekiq_staging.service << 'EOF'
[Unit]
Description=Sidekiq for cpigs-backend (staging)
After=syslog.target network.target

[Service]
Type=simple
WorkingDirectory=/var/www/cpigs-backend/current
ExecStart=/home/deploy/.rbenv/bin/rbenv exec bundle exec sidekiq -e production
EnvironmentFile=/var/www/cpigs-backend/shared/.env
Restart=always
RestartSec=5
StandardOutput=append:/var/www/cpigs-backend/shared/log/sidekiq.log
StandardError=append:/var/www/cpigs-backend/shared/log/sidekiq_error.log
SyslogIdentifier=cpigs-backend_sidekiq_staging

[Install]
WantedBy=default.target
EOF

# Enable and start
systemctl --user daemon-reload
systemctl --user enable cpigs-backend_sidekiq_staging
systemctl --user start cpigs-backend_sidekiq_staging
```

Sidekiq does **not** restart automatically on deploy — run this after each deploy
when code changed, or rely on the `Restart=always` policy for crash recovery.

Note: the unit loads env from `shared/.env` (not `shared/config/staging.env`,
which does not exist). Redis is already running as a system service on the VPS.

## Port Configuration

This application runs on port **3001** (configured in `config/puma.webdock.rb`) because port 3000 is used by another application on the VPS.

## Troubleshooting

### Check Puma status
```bash
systemctl --user status cpigs-backend_puma_staging
```

### Check Sidekiq status
```bash
systemctl --user status cpigs-backend_sidekiq_staging
```

### View Puma logs
```bash
tail -f /var/www/cpigs-backend/current/log/puma_error.log
```

### Database connection issues
Ensure PostgreSQL is accepting connections:
```bash
sudo -u postgres psql -c "SELECT 1;"
```

Check the connection in Rails:
```bash
cd /var/www/cpigs-backend/current
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"
```
