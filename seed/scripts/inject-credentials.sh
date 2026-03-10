#!/bin/sh
# inject-credentials.sh <nukeHost> <nukePort>
# POSTs Claude credentials to a running nuke container.
# Outputs JSON: { "credentialsInjected": true }

NUKE_HOST="$1"
NUKE_PORT="$2"

if [ -z "$NUKE_HOST" ] || [ -z "$NUKE_PORT" ]; then
  echo "Usage: inject-credentials.sh <nukeHost> <nukePort>" >&2
  exit 1
fi

CREDS_FILE="${CLAUDE_CREDENTIALS_PATH:-/claude-host/.credentials.json}"

if [ ! -f "$CREDS_FILE" ]; then
  echo "Credentials file not found: $CREDS_FILE" >&2
  exit 1
fi

# POST credentials to the nuke container
HTTP_CODE=$(wget --method=POST \
  --header="Content-Type: application/json" \
  --body-file="$CREDS_FILE" \
  -qO /dev/null -S \
  "http://${NUKE_HOST}:${NUKE_PORT}/credentials" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}')

if [ "$HTTP_CODE" = "200" ]; then
  echo '{"credentialsInjected":true}'
else
  echo "Failed to inject credentials: HTTP $HTTP_CODE" >&2
  exit 1
fi
