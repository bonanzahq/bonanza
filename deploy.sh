#!/usr/bin/env bash
# ABOUTME: Downloads deployment files from GitHub for a given git ref.
# ABOUTME: Run once to set up, then fill in .env and start with docker compose.

set -euo pipefail

REPO="bonanzahq/bonanza"

usage() {
  echo "Usage: ./deploy.sh [ref]"
  echo ""
  echo "Downloads docker-compose.yml, Caddyfile, and other deployment files"
  echo "from the specified git ref (default: main). Accepts branches, tags,"
  echo "or commit SHAs."
  echo ""
  echo "Requires GITHUB_TOKEN in the environment or .env file."
  echo ""
  echo "Examples:"
  echo "  ./deploy.sh          # pull from main"
  echo "  ./deploy.sh beta     # pull from beta branch"
  echo "  ./deploy.sh v2.1.2   # pull from a tag"
  exit 0
}

# Show help for -h, --help, or any flag-like argument
case "${1:-}" in
  -h|--help|-*) usage ;;
esac

[ -f .env ] && source .env

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN is required. Pass it as an environment variable or add it to .env"
  exit 1
fi

REF="${1:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${REF}"

# Validate token
if ! curl -fsSL -o /dev/null -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${REPO}" 2>/dev/null; then
  echo "Error: GITHUB_TOKEN is invalid or lacks access to ${REPO}"
  exit 1
fi

# Validate ref exists
if ! curl -fsSL -o /dev/null -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/docker/docker-compose.yml" 2>/dev/null; then
  echo "Error: ref '${REF}' not found or docker/docker-compose.yml missing at that ref"
  exit 1
fi

# Required files fail the deploy if missing. Optional files are skipped with a warning.
# Format: "remote_path:local_filename"
REQUIRED_FILES=(
  "docker-compose.yml:docker-compose.yml"
  "Caddyfile:Caddyfile"
  "elastic_synonyms.txt:elastic_synonyms.txt"
  "example.env:example.env"
)

OPTIONAL_FILES=(
  "nginx-site.conf:nginx-site.conf"
)

echo "Downloading deployment files from ${REPO}:${REF}..."

# Download required files atomically via temp directory
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

MISSING=()
for entry in "${REQUIRED_FILES[@]}"; do
  remote="${entry%%:*}"
  local_name="${entry##*:}"
  if ! curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" \
       "${BASE_URL}/docker/${remote}" -o "${TMPDIR}/${local_name}" 2>/dev/null; then
    MISSING+=("${remote}")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Error: required files missing at '${REF}':"
  for f in "${MISSING[@]}"; do
    echo "  - docker/${f}"
  done
  echo ""
  echo "This ref may predate these files. Try a newer tag or branch."
  exit 1
fi

# All required files succeeded — move to working directory
for entry in "${REQUIRED_FILES[@]}"; do
  local_name="${entry##*:}"
  mv "${TMPDIR}/${local_name}" "./${local_name}"
  echo "  ${local_name}"
done

# Optional files — skip gracefully on 404
for entry in "${OPTIONAL_FILES[@]}"; do
  remote="${entry%%:*}"
  local_name="${entry##*:}"
  if curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" \
       "${BASE_URL}/docker/${remote}" -o "./${local_name}" 2>/dev/null; then
    echo "  ${local_name} (reference)"
  else
    echo "  ${local_name} (reference) — skipped, not available at '${REF}'"
  fi
done

if [ ! -f .env ]; then
  cp example.env .env
  echo "  .env created from example.env"
fi

echo ""
echo "Done. Files pulled from '${REF}'."
echo ""
echo "Next steps:"
echo "1. Edit .env and fill in all required values (see example.env for reference)"
echo "2. Run: docker compose pull && docker compose up -d"
echo "3. Check health: docker compose ps"
