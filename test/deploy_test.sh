#!/usr/bin/env bash
# ABOUTME: Tests deploy.sh backward compatibility with old tags, new tags, and invalid refs.
# ABOUTME: Requires GITHUB_TOKEN in the environment or in .env.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy.sh"
PASS=0
FAIL=0

# Load token from .env if present
if [ -f "${SCRIPT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN required. Set it in the environment or in .env"
  exit 1
fi

export GITHUB_TOKEN

run_test() {
  local name="$1"
  local ref="$2"
  local expect_exit="$3"       # 0 or nonzero
  local expect_file="$4"       # file that must exist (or "none")
  local expect_missing="$5"    # file that must NOT exist (or "none")
  local expect_output="$6"     # substring expected in stdout/stderr (or "none")

  local tmpdir
  tmpdir=$(mktemp -d)

  echo -n "  ${name}... "

  local output exit_code
  output=$(cd "${tmpdir}" && bash "${DEPLOY_SCRIPT}" "${ref}" 2>&1) && exit_code=0 || exit_code=$?

  local ok=true

  # Check exit code
  if [ "${expect_exit}" = "0" ] && [ "${exit_code}" -ne 0 ]; then
    echo "FAIL (expected exit 0, got ${exit_code})"
    echo "    output: ${output}"
    ok=false
  elif [ "${expect_exit}" != "0" ] && [ "${exit_code}" -eq 0 ]; then
    echo "FAIL (expected nonzero exit, got 0)"
    ok=false
  fi

  # Check expected file exists
  if [ "${expect_file}" != "none" ] && [ ! -f "${tmpdir}/${expect_file}" ]; then
    echo "FAIL (expected file '${expect_file}' not found)"
    ok=false
  fi

  # Check file must NOT exist
  if [ "${expect_missing}" != "none" ] && [ -f "${tmpdir}/${expect_missing}" ]; then
    echo "FAIL (file '${expect_missing}' should not exist)"
    ok=false
  fi

  # Check output substring
  if [ "${expect_output}" != "none" ] && ! echo "${output}" | grep -q "${expect_output}"; then
    echo "FAIL (expected output containing '${expect_output}')"
    echo "    output: ${output}"
    ok=false
  fi

  if [ "${ok}" = true ]; then
    echo "OK"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi

  rm -rf "${tmpdir}"
}

echo "deploy.sh tests"
echo "================"

# Case 1: Recent branch — all files downloaded including nginx-site.conf
run_test "recent branch (beta)" \
  "beta" 0 "nginx-site.conf" "none" "Done. Files pulled from"

# Case 2: Old tag (v2.0.0) — required files present, nginx-site.conf skipped
run_test "old tag (v2.0.0) — required files present" \
  "v2.0.0" 0 "docker-compose.yml" "none" "Done. Files pulled from"

run_test "old tag (v2.0.0) — optional file skipped" \
  "v2.0.0" 0 "docker-compose.yml" "nginx-site.conf" "skipped, not available"

# Case 3: Invalid ref — fails early, no files written
run_test "invalid ref" \
  "nonexistent-branch-xyz-999" 1 "none" "docker-compose.yml" "not found"

# Case 4: Help flag
output=$(bash "${DEPLOY_SCRIPT}" --help 2>&1) && true
if echo "${output}" | grep -q "Usage:"; then
  echo "  help flag (--help)... OK"
  PASS=$((PASS + 1))
else
  echo "  help flag (--help)... FAIL"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
