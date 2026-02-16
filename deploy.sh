#!/usr/bin/env bash
# ABOUTME: Downloads production deployment files from GitHub.
# ABOUTME: Run once to set up, then fill in .env and start with docker compose.

set -euo pipefail

[ -f .env ] && source .env

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN is required. Pass it as an environment variable or add it to .env"
  exit 1
fi

REPO="bonanzahq/bonanza"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

echo "Downloading production deployment files from ${REPO}:${BRANCH}..."

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/docker-compose.yml" -o docker-compose.yml
echo "✓ docker-compose.yml"

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/Caddyfile" -o Caddyfile
echo "✓ Caddyfile"

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/elastic_synonyms.txt" -o elastic_synonyms.txt
echo "✓ elastic_synonyms.txt"

curl -fsSL -H "Authorization: token ${GITHUB_TOKEN}" "${BASE_URL}/example.env" -o example.env
echo "  example.env (reference)"

if [ ! -f .env ]; then
  cp example.env .env
  echo "  .env created from example.env"
fi

echo ""
echo "Files downloaded. Next steps:"
echo "1. Edit .env and fill in all required values (see example.env for reference)"
echo "2. Run: docker compose up -d"
echo "3. Check health: docker compose ps"
