#!/usr/bin/env bash
# review-bots-ready.sh <PR_NUMBER> <REPO>
# Waits for CI to pass, then waits for review bots to post.
# Only counts bot comments posted AFTER the latest push commit.
# Exits 0 when ready. Exits 1 on failure.

set -euo pipefail

PR_NUMBER="${1:?Usage: review-bots-ready.sh <PR_NUMBER> <REPO>}"
REPO="${2:?Usage: review-bots-ready.sh <PR_NUMBER> <REPO>}"

# Step 1: Wait for CI
echo "Waiting for CI checks on PR #${PR_NUMBER}..." >&2
gh pr checks "${PR_NUMBER}" --repo "${REPO}" --watch --interval 15 2>/dev/null || true

# Check if CI actually passed
FAILED=$(gh pr checks "${PR_NUMBER}" --repo "${REPO}" --json name,status,conclusion \
  --jq '[.[] | select(.conclusion == "FAILURE")] | length' 2>/dev/null || echo "0")

if [ "${FAILED}" -gt "0" ]; then
  echo "{\"outcome\":\"ci_failed\",\"message\":\"${FAILED} check(s) failing on PR #${PR_NUMBER}\"}"
  exit 1
fi

# Step 1b: Check if this repo has review bots configured (historical check)
HISTORICAL_INLINE=$(gh api "repos/${REPO}/pulls/comments?per_page=5&sort=created&direction=desc" \
  --jq '[.[] | select(.user.login | test("qodo|coderabbit|devin|sourcery"; "i"))] | length' 2>/dev/null || echo "0")

HISTORICAL_TOP=$(gh api "repos/${REPO}/issues/comments?per_page=5&sort=created&direction=desc" \
  --jq '[.[] | select(.user.login | test("qodo|coderabbit|devin|sourcery"; "i"))] | length' 2>/dev/null || echo "0")

HISTORICAL_BOTS=$(( HISTORICAL_INLINE + HISTORICAL_TOP ))

if [ "${HISTORICAL_BOTS}" -eq "0" ]; then
  echo "No review bots configured for ${REPO}. Proceeding with CI-only gate." >&2
  echo '{"outcome":"ready","message":"CI green, no bots configured"}'
  exit 0
fi

echo "Review bots detected for ${REPO} (${HISTORICAL_BOTS} historical comments). Waiting for fresh comments..." >&2

# Step 2: Get the timestamp of the latest push commit on the PR branch
LATEST_PUSH_AT=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}" \
  --jq '.head.sha' 2>/dev/null | xargs -I{} \
  gh api "repos/${REPO}/commits/{}" --jq '.commit.committer.date' 2>/dev/null || echo "")

if [ -z "${LATEST_PUSH_AT}" ]; then
  echo "Could not determine latest push timestamp; falling back to no timestamp filter." >&2
  LATEST_PUSH_AT="1970-01-01T00:00:00Z"
fi

echo "Latest push at: ${LATEST_PUSH_AT}" >&2

# Step 3: Wait for review bots (up to 10 minutes), counting only comments AFTER the latest push
echo "Waiting for review bots on PR #${PR_NUMBER} (after ${LATEST_PUSH_AT})..." >&2
DEADLINE=$(( $(date +%s) + 600 ))

while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
  BOT_COUNT=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" 2>/dev/null \
    | jq --arg since "${LATEST_PUSH_AT}" \
    '[.[] | select(.user.login | test("qodo|coderabbit|devin|sourcery"; "i")) | select(.created_at > $since)] | length' 2>/dev/null || echo "0")

  TOP_COUNT=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" 2>/dev/null \
    | jq --arg since "${LATEST_PUSH_AT}" \
    '[.[] | select(.user.login | test("qodo|coderabbit|devin|sourcery"; "i")) | select(.created_at > $since)] | length' 2>/dev/null || echo "0")

  TOTAL=$(( BOT_COUNT + TOP_COUNT ))
  if [ "${TOTAL}" -gt "0" ]; then
    echo "{\"outcome\":\"ready\",\"message\":\"CI green, ${TOTAL} bot comments posted\"}"
    exit 0
  fi

  echo "No bot comments since latest push yet, waiting 30s..." >&2
  sleep 30
done

echo "Review bots expected but none posted within 10 minutes." >&2
echo "{\"outcome\":\"bot_timeout\",\"message\":\"Review bots expected but did not post within 10 minutes on PR #${PR_NUMBER}\"}"
exit 1
