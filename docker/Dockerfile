# ABOUTME: Builds the Rails application image for development and production.
# ABOUTME: Uses multi-stage builds: build (compile), production (slim runtime), development (adds Node.js).

FROM ruby:4.0.1-slim AS build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      libyaml-dev \
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

FROM ruby:4.0.1-slim AS production

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libpq5 \
      postgresql-client \
      curl && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 rails

COPY --from=build /usr/local/bundle /usr/local/bundle

WORKDIR /app
COPY --chown=rails:rails --from=build /app /app

USER rails

ENTRYPOINT ["./docker/docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

FROM production AS development

USER root

RUN apt-get update -qq && \
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Workaround: pnpm 10 aborts with ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY
# when node_modules needs recreating in a non-TTY environment (Docker).
ENV CI=true

RUN corepack enable && corepack prepare pnpm@10 --activate

USER rails
