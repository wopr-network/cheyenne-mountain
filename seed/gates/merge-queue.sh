#!/bin/sh
# merge-queue.sh <prNumber> <repo>
# Waits for CI, queues auto-merge, then polls until merged, failed, or timeout.
# Emits a JSON outcome line on the last line of output for silo gate routing.

set -e

PR_NUMBER="$1"
REPO="$2"

if [ -z "$PR_NUMBER" ] || [ -z "$REPO" ]; then
  echo "Usage: merge-queue.sh <prNumber> <repo>" >&2
  exit 1
fi

# Step 1: Wait for all CI checks to complete before attempting merge
echo "Waiting for CI checks on PR #${PR_NUMBER}..." >&2
gh pr checks "$PR_NUMBER" --repo "$REPO" --watch --interval 15 2>/dev/null || true

# Check for CI failures
FAILED=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --json name,state \
  --jq '[.[] | select(.state == "FAILURE")] | length' 2>/dev/null || echo "0")

if [ "${FAILED}" -gt "0" ]; then
  NAMES=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --json name,state \
    --jq '[.[] | select(.state == "FAILURE") | .name] | join(", ")' 2>/dev/null || echo "unknown")
  echo "{\"outcome\":\"blocked\",\"message\":\"CI failing on PR #${PR_NUMBER}: ${NAMES}\"}"
  exit 1
fi

# Step 2: CI passed — queue auto-merge (idempotent)
gh pr merge "$PR_NUMBER" --repo "$REPO" --squash --auto 2>/dev/null || true

# Step 3: Poll until merged or definitively failed (max 30 x 30s = 15 min)
ATTEMPTS=0
while [ "$ATTEMPTS" -lt 30 ]; do
  STATUS=$(gh pr view "$PR_NUMBER" --repo "$REPO" \
    --json state,mergeStateStatus \
    --jq '"state=" + .state + " merge=" + .mergeStateStatus')

  case "$STATUS" in
    *state=MERGED*)
      echo "{\"outcome\":\"merged\",\"message\":\"PR #${PR_NUMBER} merged successfully\"}"
      exit 0
      ;;
    *state=CLOSED*)
      echo "{\"outcome\":\"closed\",\"message\":\"PR #${PR_NUMBER} was closed without merging\"}"
      exit 1
      ;;
  esac

  # BLOCKED/CLEAN/UNSTABLE are transient — auto-merge handles it, keep polling
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 30
done

echo "{\"outcome\":\"blocked\",\"message\":\"Timed out waiting for PR #${PR_NUMBER} after 15 minutes. Last status: ${STATUS}\"}"
exit 1
