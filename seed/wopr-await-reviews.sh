#!/usr/bin/env bash
# wopr-await-reviews.sh <PR_NUMBER> <REPO>
# Waits for CI checks to complete, then dumps all PR comments.

set -euo pipefail

PR_NUMBER="${1:?Usage: wopr-await-reviews.sh <PR_NUMBER> <REPO>}"
REPO="${2:?Usage: wopr-await-reviews.sh <PR_NUMBER> <REPO>}"

dump_reviews() {
  echo ""
  echo "=== INLINE REVIEW COMMENTS ==="
  gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" \
    --jq '.[] | "[\(.user.login)] \(.path):\(.line // "?") — \(.body)"' 2>/dev/null || true

  echo ""
  echo "=== FORMAL REVIEWS ==="
  gh pr view "${PR_NUMBER}" --repo "${REPO}" --json reviews \
    --jq '.reviews[]? | "[\(.author.login) / \(.state)] \(.body)"' 2>/dev/null || true

  echo ""
  echo "=== TOP-LEVEL COMMENTS ==="
  gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
    --jq '.[] | "[\(.user.login)] \(.body)"' 2>/dev/null || true
}

echo "Waiting for CI checks to complete..." >&2
if ! gh pr checks "${PR_NUMBER}" --repo "${REPO}" --watch --interval 10 2>/dev/null; then
  echo "ERROR: CI checks failed for PR #${PR_NUMBER}" >&2
  exit 1
fi

echo "ALL_POSTED: CI complete for PR #${PR_NUMBER}"
dump_reviews
