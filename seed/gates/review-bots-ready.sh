#!/usr/bin/env bash
# review-bots-ready.sh <PR_NUMBER> <REPO>
# Waits for all CI checks to complete.
# Any failure → ci_failed (routes to fixer). All pass → ready (routes to review).

set -euo pipefail

PR_NUMBER="${1:?Usage: review-bots-ready.sh <PR_NUMBER> <REPO>}"
REPO="${2:?Usage: review-bots-ready.sh <PR_NUMBER> <REPO>}"

# Wait for all checks to finish
echo "Waiting for CI checks on PR #${PR_NUMBER}..." >&2
gh pr checks "${PR_NUMBER}" --repo "${REPO}" --watch --interval 15 2>/dev/null || true

# Check for failures (gh pr checks uses "state", not "conclusion")
FAILED=$(gh pr checks "${PR_NUMBER}" --repo "${REPO}" --json name,state \
  --jq '[.[] | select(.state == "FAILURE")] | length' 2>/dev/null || echo "0")

if [ "${FAILED}" -gt "0" ]; then
  NAMES=$(gh pr checks "${PR_NUMBER}" --repo "${REPO}" --json name,state \
    --jq '[.[] | select(.state == "FAILURE") | .name] | join(", ")' 2>/dev/null || echo "unknown")
  echo "{\"outcome\":\"ci_failed\",\"message\":\"${FAILED} check(s) failing on PR #${PR_NUMBER}: ${NAMES}\"}"
  exit 1
fi

echo "{\"outcome\":\"ready\",\"message\":\"All checks passed on PR #${PR_NUMBER}\"}"
exit 0
