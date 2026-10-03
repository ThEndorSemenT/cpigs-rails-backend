FROM ruby:3.3.4-slim

WORKDIR /rails

ENV RAILS_ENV=development \
    GEM_HOME=/usr/local/bundle/ruby/3.3.0 \
    GEM_PATH=/usr/local/bundle/ruby/3.3.0 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=""
ENV PATH=/usr/local/bundle/ruby/3.3.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      libsecp256k1-dev \
      autoconf \
      automake \
      libtool \
      curl \
      git \
      nano \
    && rm -rf /var/lib/apt/lists/*

# Install gems — copy manifests first so Docker layer cache is reused
# when only app code changes.
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4

# Copy application code (may not include Gemfile.lock on the host)
COPY . .

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
