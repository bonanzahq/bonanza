# ABOUTME: Builds the Rails application image for development and production.
# ABOUTME: Installs Ruby gems, Node/pnpm packages, and compiles frontend assets.

FROM ruby:4.0.1 AS build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      curl && \
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@10 --activate

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install foreman && bundle install

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

RUN SECRET_KEY_BASE=precompile-placeholder \
    RAILS_ENV=production \
    bundle exec rails assets:precompile

FROM ruby:4.0.1 AS production

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libpq-dev \
      postgresql-client \
      curl && \
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@10 --activate

RUN useradd -m -u 1000 rails

COPY --from=build /usr/local/bundle /usr/local/bundle

WORKDIR /app
COPY --chown=rails:rails --from=build /app /app

USER rails

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
