#!/bin/sh
# setup-nuke.sh <nukeHost> <nukePort>
# Injects credentials (Claude + GitHub) into a nuke container.
# Called by onProvision after container launch.
set -e

NUKE_HOST="$1"
NUKE_PORT="$2"

if [ -z "$NUKE_HOST" ] || [ -z "$NUKE_PORT" ]; then
  echo "Usage: setup-nuke.sh <nukeHost> <nukePort>" >&2
  exit 1
fi

# --- Inject credentials ---

CLAUDE_CREDS_FILE="${CLAUDE_CREDENTIALS_PATH:-/claude-host/.credentials.json}"
CREDS_BODY="{}"

# Build credentials payload
if [ -f "$CLAUDE_CREDS_FILE" ]; then
  CLAUDE_JSON=$(cat "$CLAUDE_CREDS_FILE")
else
  CLAUDE_JSON=""
fi

if [ -n "$GH_TOKEN" ]; then
  GH_PART="\"github\":{\"token\":\"${GH_TOKEN}\"}"
else
  GH_PART=""
fi

if [ -n "$CLAUDE_JSON" ] && [ -n "$GH_PART" ]; then
  CREDS_BODY="{\"claude\":${CLAUDE_JSON},${GH_PART}}"
elif [ -n "$CLAUDE_JSON" ]; then
  CREDS_BODY="{\"claude\":${CLAUDE_JSON}}"
elif [ -n "$GH_PART" ]; then
  CREDS_BODY="{${GH_PART}}"
else
  echo "Warning: no credentials to inject" >&2
fi

if [ "$CREDS_BODY" != "{}" ]; then
  CREDS_RESULT=$(wget -qO- --method=POST \
    --header="Content-Type: application/json" \
    --body-data="$CREDS_BODY" \
    "http://${NUKE_HOST}:${NUKE_PORT}/credentials" 2>&1) || {
    echo "Failed to inject credentials: $CREDS_RESULT" >&2
    exit 1
  }
  echo "Credentials injected: $CREDS_RESULT" >&2
fi
