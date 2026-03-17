# Slim Docker Image

Branch: `slim-docker-image`
PR: #242
GitHub issues: #91 (Remove Node.js from production image), #93 (Switch to ruby-slim)
git-bug issues: 5af0461, 4f8af1b (both closed)

## What was done

Switched the production Docker image from `ruby:4.0.1` (full Debian, 1.72GB)
to `ruby:4.0.1-slim` (530MB, 69% reduction) and removed Node.js from the
production stage.

### Dockerfile restructured into three stages

1. **build** (`ruby:4.0.1-slim`) -- compiles gems, installs Node.js/pnpm,
   precompiles assets. Unchanged role, just switched base.
2. **base** (`ruby:4.0.1-slim`) -- slim runtime with only `libpq5`,
   `postgresql-client`, `curl`. No Node.js. Shared by production and
   development.
3. **development** (`FROM base`) -- adds Node.js and pnpm back for
   Docker-based dev (asset watchers via Procfile.dev).
4. **production** (`FROM base`) -- final stage, intentionally last so a
   default `docker build` without `--target` produces the slim production
   image.

### Key decisions

- **`libyaml-dev` needed in build stage**: The `psych` gem (dependency of
  Rails via rdoc/irb) needs `yaml.h` to compile. The full Ruby image includes
  this; slim does not. First build failed on this. The runtime lib
  (`libyaml-0-2`) is already in the slim base.

- **`libpq-dev` replaced with `libpq5`**: Production only needs the shared
  library, not development headers. The `pg` gem compiles in the build stage.

- **Stage ordering matters**: Copilot caught that having `development` as the
  last stage would make it the default build target. Fixed by making
  `production` the final stage (`FROM base AS production`). The CI workflow
  (`docker-build.yml`) doesn't specify `--target`, so this was important.

- **Compose override updated**: Added `target: development` to both `rails`
  and `worker` service build configs so `docker compose up --build` from
  `docker/` uses the development stage.

### Documentation updated

- AGENTS.md: Added "Building without Compose" section explaining that
  standalone `docker build` must run from the repo root with
  `-f docker/Dockerfile`.
- README.md: Same info added under Development section.

### Verification

- All native gems load in production image (pg, nokogiri, puma, bcrypt, psych)
- Node.js and pnpm confirmed absent from production image
- Full test suite passes (675 tests, 0 failures)
- E2E testing through browser: login, equipment listing, search, item
  creation, borrower management, statistics, staff management, legal texts,
  logout, public registration -- all working
- Container logs clean, worker (solid_queue) healthy

## New issue created

- #243: Add automated table of contents generation for markdown files
  (doctoc, for README.md and AGENTS.md -- separate branch)
