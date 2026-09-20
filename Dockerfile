FROM ruby:3.3.4-slim

WORKDIR /rails

ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=""

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      curl \
      git \
      nano \
    && rm -rf /var/lib/apt/lists/*

# Install gems — copy manifests first so Docker layer cache is reused
# when only app code changes.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code (may not include Gemfile.lock on the host)
COPY . .

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
