#!/bin/sh
# merge-queue.sh <prNumber> <repo>
# Queues auto-merge on the PR then polls until merged, failed, or timeout.
# Emits a JSON outcome line on the last line of output for defcon gate routing.
# Exits 0 on MERGED. Exits 1 on failure/closed. Times out after ~15 min.

set -e

PR_NUMBER="$1"
REPO="$2"

if [ -z "$PR_NUMBER" ] || [ -z "$REPO" ]; then
  echo "Usage: merge-queue.sh <prNumber> <repo>" >&2
  exit 1
fi

# Queue auto-merge (idempotent — safe to call even if already queued)
gh pr merge "$PR_NUMBER" --repo "$REPO" --squash --auto 2>/dev/null || true

# Poll until resolved (max 30 attempts × 30s = 15 minutes)
ATTEMPTS=0
while [ "$ATTEMPTS" -lt 30 ]; do
  STATUS=$(gh pr view "$PR_NUMBER" --repo "$REPO" \
    --json state,mergeStateStatus \
    --jq '"state=" + .state + " merge=" + .mergeStateStatus' 2>/dev/null) || {
    echo "WARN: gh pr view failed, retrying..." >&2
    ATTEMPTS=$((ATTEMPTS + 1))
    sleep 30
    continue
  }

  case "$STATUS" in
    *state=MERGED*)
      echo '{"outcome":"merged","message":"PR #'"$PR_NUMBER"' merged successfully"}'
      exit 0
      ;;
    *state=CLOSED*)
      echo '{"outcome":"closed","message":"PR #'"$PR_NUMBER"' was closed without merging"}'
      exit 1
      ;;
    *merge=BLOCKED*)
      # BLOCKED is often transient (waiting for required checks). Keep polling.
      echo "PR #${PR_NUMBER} is BLOCKED (likely waiting for checks), continuing to poll..." >&2
      ;;
  esac

  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 30
done

echo '{"outcome":"blocked","message":"Timed out waiting for PR #'"$PR_NUMBER"' after 15 minutes. Last status: '"${STATUS:-unknown}"'"}'
exit 1
