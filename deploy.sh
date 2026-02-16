#!/usr/bin/env bash
# ABOUTME: Downloads production deployment files from GitHub.
# ABOUTME: Run once to set up, then fill in .env and start with docker compose.

set -euo pipefail

REPO="bonanzahq/bonanza"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

echo "Downloading production deployment files from ${REPO}:${BRANCH}..."

curl -fsSL "${BASE_URL}/docker-compose.yml" -o docker-compose.yml
echo "✓ docker-compose.yml"

curl -fsSL "${BASE_URL}/Caddyfile" -o Caddyfile
echo "✓ Caddyfile"

curl -fsSL "${BASE_URL}/elastic_synonyms.txt" -o elastic_synonyms.txt
echo "✓ elastic_synonyms.txt"

if [ -f .env ]; then
  echo "✓ .env already exists, skipping example.env download"
else
  curl -fsSL "${BASE_URL}/example.env" -o .env
  echo "✓ example.env downloaded as .env"
fi

echo ""
echo "Files downloaded. Next steps:"
echo "1. Edit .env and fill in all values"
echo "2. Run: docker compose up -d"
echo "3. Check health: docker compose ps"
