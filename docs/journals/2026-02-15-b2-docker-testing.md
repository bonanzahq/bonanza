# B2 Error Handling - Docker Testing & .env Fix

## Branch: feat-error-handling

## What happened

Resumed work to test the B2 error handling PR (#57) on the running Docker
stack. The rails container was crash-looping with:

```
`secret_key_base` for development environment must be a type of String` (ArgumentError)
```

### Root cause

A `.env` file in the project root (created in a prior session to silence
Docker Compose warnings about unset variables) had `SECRET_KEY_BASE=` (empty).
Docker Compose resolved the override's `SECRET_KEY_BASE: dev-not-secret`
correctly, BUT foreman (which runs inside the container at `/app`) also reads
`.env` from its working directory. The volume mount `./:/app` made the root
`.env` visible to foreman, which overwrote the Docker env var with an empty
string. Rails 8.1 rejects empty strings in `secret_key_base=`.

### Fix

1. Deleted the `.env` file
2. Added `${VAR:-}` empty default syntax to all env var references in
   `docker-compose.yml` so Docker Compose doesn't warn about unset vars
   (commit `3158686`)

### Docker testing results

All services healthy after the fix:
- `curl localhost:3000/health/liveness` -> `{"status":"ok"}`
- `curl localhost:3000/health/readiness` -> `{"status":"ok","checks":{"database":{"status":"ok"},"elasticsearch":{"status":"ok"}}}`
- Dozzle running on port 9999

### Follow-up: docker/ directory restructure

The `.env` conflict between Docker Compose and foreman is a structural
problem. Wrote a plan (`docs/plans/docker-directory-restructure.md`) to move
all Docker infra files into a `docker/` subdirectory, so `.env` lives where
only Docker Compose reads it. Filed as git-bug `a09b6ba`.

Two decisions pending from Fabian:
- Entrypoint file location (recommend: move to docker/, explicit COPY in Dockerfile)
- Convenience wrapper for docker compose commands (recommend: bin/dc script)

## Commits this session

- `3158686` fix(docker): add default values for env vars to silence compose warnings
- `54d02bf` docs(plans): add docker directory restructure plan

## Issues

- Closed `9b6a588` (Execute b2: Error handling and observability)
- Created `a09b6ba` (Move Docker infrastructure files into docker/ subdirectory)
