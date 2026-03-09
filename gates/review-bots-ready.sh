#!/usr/bin/env bash
# review-bots-ready.sh <PR_NUMBER> <REPO>
# Waits for CI to pass, then waits for review bots to post.
# Exits 0 when ready. Exits 1 on failure.

set -euo pipefail

PR_NUMBER="${1:?Usage: review-bots-ready.sh <PR_NUMBER> <REPO>}"
REPO="${2:?Usage: review-bots-ready.sh <PR_NUMBER> <REPO>}"

# Step 1: Wait for CI
echo "Waiting for CI checks on PR #${PR_NUMBER}..." >&2
gh pr checks "${PR_NUMBER}" --repo "${REPO}" --watch --interval 15 2>/dev/null || true

# Check if CI actually passed
FAILED=$(gh pr checks "${PR_NUMBER}" --repo "${REPO}" --json name,status,conclusion \
  --jq '[.[] | select(.conclusion | ascii_downcase == "failure")] | length' 2>/dev/null || echo "0")

if [ "${FAILED}" -gt "0" ]; then
  echo "CI failed: ${FAILED} check(s) failing on PR #${PR_NUMBER}"
  exit 1
fi

# Step 2: Wait for review bots (up to 10 minutes)
echo "Waiting for review bots on PR #${PR_NUMBER}..." >&2
DEADLINE=$(( $(date +%s) + 600 ))

while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
  BOT_COUNT=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" \
    --jq '[.[] | select(.user.login | test("bot|qodo|coderabbit|devin|sourcery"; "i"))] | length' \
    2>/dev/null || echo "0")

  TOP_COUNT=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
    --jq '[.[] | select(.user.login | test("bot|qodo|coderabbit|devin|sourcery"; "i"))] | length' \
    2>/dev/null || echo "0")

  TOTAL=$(( BOT_COUNT + TOP_COUNT ))
  if [ "${TOTAL}" -gt "0" ]; then
    echo "Review bots posted (${TOTAL} comment(s)). PR #${PR_NUMBER} ready for review."
    exit 0
  fi

  echo "No bot comments yet, waiting 30s..." >&2
  sleep 30
done

echo "WARN: Timed out waiting for review bots on PR #${PR_NUMBER}. Proceeding with 0 bot comments." >&2
echo "Proceeding without bot comments — reviewer will work with diff only."
exit 0
