#!/usr/bin/env bash
# ABOUTME: Downloads deployment files from GitHub for a given branch.
# ABOUTME: Run once to set up, then fill in .env and start with docker compose.

set -euo pipefail

REPO="bonanzahq/bonanza"

usage() {
  echo "Usage: ./deploy.sh [branch]"
  echo ""
  echo "Downloads docker-compose.yml, Caddyfile, and other deployment files"
  echo "from the specified branch (default: main)."
  echo ""
  echo "Requires GITHUB_TOKEN in the environment or .env file."
  echo ""
  echo "Examples:"
  echo "  ./deploy.sh          # pull from main"
  echo "  ./deploy.sh beta     # pull from beta"
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

BRANCH="${1:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

# Validate token
if ! curl -fsSL -o /dev/null -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${REPO}" 2>/dev/null; then
  echo "Error: GITHUB_TOKEN is invalid or lacks access to ${REPO}"
  exit 1
fi

# Validate branch exists
if ! curl -fsSL -o /dev/null -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/docker-compose.yml" 2>/dev/null; then
  echo "Error: branch '${BRANCH}' not found or docker-compose.yml missing on that branch"
  exit 1
fi

echo "Downloading deployment files from ${REPO}:${BRANCH}..."

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/docker-compose.yml" -o docker-compose.yml
echo "  docker-compose.yml"

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/Caddyfile" -o Caddyfile
echo "  Caddyfile"

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/elastic_synonyms.txt" -o elastic_synonyms.txt
echo "  elastic_synonyms.txt"

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/example.env" -o example.env
echo "  example.env (reference)"

if [ ! -f .env ]; then
  cp example.env .env
  echo "  .env created from example.env"
fi

echo ""
echo "Done. Files pulled from '${BRANCH}'."
echo ""
echo "Next steps:"
echo "1. Edit .env and fill in all required values (see example.env for reference)"
echo "2. Run: docker compose pull && docker compose up -d"
echo "3. Check health: docker compose ps"
