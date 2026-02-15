# Docker Directory Restructure

## Problem

Docker Compose reads `.env` from its working directory. Foreman (which runs
inside the Rails container at `/app`) also reads `.env` from its working
directory. Since the project root is volume-mounted at `/app`, any `.env`
file meant for Docker Compose gets picked up by Foreman, causing env var
conflicts (e.g., empty `SECRET_KEY_BASE` overriding the value from
docker-compose.override.yml).

Currently all Docker infrastructure files are mixed in with the Rails app
root, making it unclear what belongs to Docker and what belongs to Rails.

## Proposed Layout

Move Docker infrastructure into a `docker/` subdirectory:

```
docker/
  Dockerfile
  docker-compose.yml
  docker-compose.override.yml
  docker-entrypoint.sh
  Caddyfile
  .env.example
  .env                  (gitignored, only read by Docker Compose)
```

Stays in project root (Rails or shared):
```
Procfile.dev            (foreman runs from /app, must find this)
.dockerignore           (must be in Docker build context root)
elastic_synonyms.txt    (app config, mounted into ES container)
bin/backup              (shell scripts, run from project root)
bin/restore
```

## Why `docker/` and Not a Source Subfolder

A `src/` approach (mounting only app code) would require changing every
Rails path convention. A `docker/` folder keeps Rails untouched and groups
all container config together.

## Implementation Steps

### Step 1: Move files

```
mkdir docker/
git mv Dockerfile docker/
git mv docker-compose.yml docker/
git mv docker-compose.override.yml docker/
git mv docker-entrypoint.sh docker/
git mv Caddyfile docker/
git mv .env.example docker/
```

### Step 2: Update docker-compose.yml

All paths are relative to the compose file's location (`docker/`).

| Current | New | Why |
|---------|-----|-----|
| `build: .` | `build: context: .. dockerfile: docker/Dockerfile` | Build context must be project root for COPY commands |
| `./elastic_synonyms.txt:/...` | `../elastic_synonyms.txt:/...` | One directory up |
| `./Caddyfile:/etc/caddy/Caddyfile:ro` | `./Caddyfile:/etc/caddy/Caddyfile:ro` | Caddyfile moves with compose |

### Step 3: Update docker-compose.override.yml

| Current | New | Why |
|---------|-----|-----|
| `.:/app` | `../:/app` | Mount project root, not docker/ |
| `build: .` | `build: context: .. dockerfile: docker/Dockerfile` | Same as base |

### Step 4: Update Dockerfile

The build context is the project root (`..` from docker/), so COPY paths
stay the same. But ENTRYPOINT references the script:

| Current | New |
|---------|-----|
| `COPY . .` | `COPY . .` (unchanged, context is project root) |
| `ENTRYPOINT ["./docker-entrypoint.sh"]` | `ENTRYPOINT ["./docker/docker-entrypoint.sh"]` |

Wait -- COPY copies from the build context into the image at WORKDIR.
If build context is the project root, `COPY . .` copies everything
including `docker/`. The entrypoint script will be at `/app/docker/docker-entrypoint.sh`
inside the image. So ENTRYPOINT path changes.

Alternative: keep `docker-entrypoint.sh` in the project root to avoid
this. **Decision needed from Fabian.**

Option A: Move entrypoint to docker/, update ENTRYPOINT path.
  - Pro: all Docker files together
  - Con: slightly unusual path in ENTRYPOINT

Option B: Keep entrypoint in project root, only move compose/Dockerfile/Caddyfile.
  - Pro: simpler Dockerfile
  - Con: one Docker file left in root

Option C: COPY the entrypoint explicitly in Dockerfile to a known path.
  ```dockerfile
  COPY docker/docker-entrypoint.sh /app/docker-entrypoint.sh
  ENTRYPOINT ["./docker-entrypoint.sh"]
  ```
  - Pro: clean image layout, all source files in docker/
  - Con: extra COPY line

**Recommendation: Option C.** It keeps all infra files in docker/ while
maintaining a clean image layout.

### Step 5: Update .dockerignore

`.dockerignore` must stay in the project root (build context root). Add
the docker/ folder itself to ignores since the Dockerfile and compose
files aren't needed in the image:

```
docker/docker-compose*.yml
docker/Caddyfile
docker/.env*
```

Keep `docker/docker-entrypoint.sh` and `docker/Dockerfile` accessible
(Dockerfile is needed by BuildKit, entrypoint is COPYed).

### Step 6: Update CI workflows

**.github/workflows/docker-build.yml:**
```yaml
- name: Build and push
  uses: docker/build-push-action@v6
  with:
    context: .
    file: docker/Dockerfile       # Add this line
    push: ...
```

**.github/workflows/test.yml:** No changes needed (doesn't use Docker).

### Step 7: Update bin/backup and bin/restore

These scripts use `docker compose exec`. They need to either:
- Use `-f docker/docker-compose.yml` flag
- Or assume they're run from the `docker/` directory

**Recommendation:** Add `-f docker/docker-compose.yml` to the commands.
Scripts should work from the project root since that's where developers
will be.

```bash
docker compose -f docker/docker-compose.yml exec -T db pg_dump ...
```

### Step 8: Create .env in docker/

Create `docker/.env` with empty defaults for production-only vars.
Docker Compose reads it automatically when run from docker/. Foreman
in the container never sees it because the volume mount is `../:/app`
which maps to the project root, not docker/.

Wait -- if we use `-f docker/docker-compose.yml` from the project root,
Docker Compose resolves `.env` relative to the compose file's directory
(docker/). So `.env` in docker/ is correct.

But if someone `cd docker && docker compose up`, it also works. Good.

Revert the `${VAR:-}` defaults in docker-compose.yml back to `${VAR}`
since the .env file will always exist in docker/.

**Actually, keep `${VAR:-}` as belt-and-suspenders.** If someone forgets
to create .env, warnings are less confusing than hard failures.

### Step 9: Update documentation

Files to update:
- `docs/structure/docker.md` -- file layout table, all paths
- `AGENTS.md` (worktree root) -- docker compose commands
- `AGENTS.md` (project) -- Docker commands section
- `README.md` (if it exists) -- getting started instructions

### Step 10: Add convenience wrapper

To avoid typing `-f docker/docker-compose.yml` everywhere, add a thin
wrapper:

**Option A:** `COMPOSE_FILE` env var in a project-root `.env` that
foreman won't conflict with (since it only contains COMPOSE_FILE, not
Rails vars). Actually this brings back the original .env problem.

**Option B:** Shell alias in docs. Not enforceable.

**Option C:** A `bin/docker-compose` wrapper script:
```bash
#!/bin/bash
exec docker compose -f docker/docker-compose.yml "$@"
```

**Option D:** Set `COMPOSE_FILE` in the shell profile or direnv.

**Recommendation:** Document the `-f` flag in AGENTS.md and add a
`bin/dc` wrapper script for convenience. Keep it simple.

**Decision needed from Fabian.**

## Files to Move

| From | To |
|------|----|
| `Dockerfile` | `docker/Dockerfile` |
| `docker-compose.yml` | `docker/docker-compose.yml` |
| `docker-compose.override.yml` | `docker/docker-compose.override.yml` |
| `docker-entrypoint.sh` | `docker/docker-entrypoint.sh` |
| `Caddyfile` | `docker/Caddyfile` |
| `.env.example` | `docker/.env.example` |

## Files to Modify

| File | Change |
|------|--------|
| `docker/docker-compose.yml` | Update build context, volume mount paths |
| `docker/docker-compose.override.yml` | Update build context, volume mount paths |
| `docker/Dockerfile` | Add explicit COPY for entrypoint |
| `.dockerignore` | Add docker/ exclusions |
| `.github/workflows/docker-build.yml` | Add `file: docker/Dockerfile` |
| `bin/backup` | Add `-f docker/docker-compose.yml` |
| `bin/restore` | Add `-f docker/docker-compose.yml` |
| `docs/structure/docker.md` | Update all paths |
| `AGENTS.md` (project) | Update docker compose commands |

## Files to Create

| File | Purpose |
|------|---------|
| `docker/.env` | Default env vars for Docker Compose (gitignored) |
| `docker/.env.example` | (moved from root) |

## Risks

1. **Build context change**: The Docker build context becomes `..` (project
   root) referenced from docker/. This is the same content as before, just
   referenced differently. `.dockerignore` stays in the project root and
   continues to work.

2. **Developer muscle memory**: `docker compose up` from project root will
   fail. Need to either `cd docker/` or use `-f`. This is the biggest UX
   impact.

3. **CI cache invalidation**: Changing the Dockerfile path may invalidate
   GitHub Actions Docker layer cache. One-time cost.

## Decisions Needed

1. **Entrypoint location**: Option A (move to docker/, update ENTRYPOINT
   path), Option B (keep in root), or Option C (move to docker/, explicit
   COPY in Dockerfile). Recommendation: C.

2. **Convenience wrapper**: How to make `docker compose` commands easy from
   the project root. Options: bin/dc script, documented -f flag, or
   COMPOSE_FILE env var. Recommendation: bin/dc + docs.

## Testing

- [ ] `docker compose -f docker/docker-compose.yml config` resolves correctly
- [ ] `docker compose -f docker/docker-compose.yml up -d` starts all services
- [ ] No env var warnings from Docker Compose (docker/.env present)
- [ ] Foreman inside container does NOT read docker/.env
- [ ] `bin/backup` and `bin/restore` still work
- [ ] CI docker-build workflow passes
- [ ] CI test workflow passes (should be unaffected)
- [ ] All existing tests pass
