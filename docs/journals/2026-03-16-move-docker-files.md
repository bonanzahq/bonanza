# Move Docker Files to docker/ Subdirectory

Branch: `move-docker-files`
PR: #237 (against beta)
GitHub issue: #66
git-bug: a09b6ba (closed)

## What we did

Moved all Docker infrastructure files from the project root into a `docker/`
subdirectory to separate container configuration from the Rails application
and eliminate `.env` conflicts between Docker Compose and Foreman.

### Files moved

Dockerfile, docker-compose.yml, docker-compose.override.yml,
docker-entrypoint.sh, Caddyfile, example.env, elastic_synonyms.txt
-- all into `docker/`.

### Key changes

- Override compose: build context `..` + `dockerfile: docker/Dockerfile`,
  volume `..:/app` to mount project root
- CI workflow: `file: docker/Dockerfile` in build-push-action
- deploy.sh: all GitHub raw download URLs use `docker/` prefix
- bin/backup, bin/restore: `--project-directory docker`
- .dockerignore: exclude compose/config files from build context
- Documentation updated (AGENTS.md, README.md, docs/structure/docker.md)

### Entrypoint path bug

The initial implementation had the Dockerfile COPY entrypoint to
`/app/docker-entrypoint.sh` with `ENTRYPOINT ["./docker-entrypoint.sh"]`.
This worked in production (image filesystem) but broke in dev where
`..:/app` volume mount overlays `/app` with the repo root -- hiding the
copied file.

First fix: added `entrypoint:` override in docker-compose.override.yml.
Final fix: changed ENTRYPOINT to `["./docker/docker-entrypoint.sh"]` and
removed the explicit COPY. This path works in both environments because
`COPY . .` in the build stage puts it at `/app/docker/docker-entrypoint.sh`
in the image, and the dev volume mount provides it at the same path.

### Migration script default reverted

Copilot review caught that changing the COMPOSE_FILE default in
`scripts/migration/02-run-migration.sh` to `docker/docker-compose.yml`
would break server usage -- those scripts are scp'd to servers where
deploy.sh puts files flat. Reverted to `docker-compose.yml`.

## Lessons

- When files move into a subdirectory but the dev compose mounts the repo
  root, any Dockerfile COPY that places files at a different path than the
  repo layout will break under the volume mount. Use repo-relative paths
  in ENTRYPOINT so the same path works with and without the mount.
- Scripts that run on deployment servers (via deploy.sh flat layout) should
  not assume the repo's directory structure.
- Spawning a fresh agent session with minimal instructions is a good smoke
  test -- it found the entrypoint bug immediately.
