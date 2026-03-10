#!/bin/sh
set -e

# Copy Claude credentials if available
mkdir -p /home/node/.claude
cp /claude-host/.credentials.json /home/node/.claude/.credentials.json 2>/dev/null || true

# Determine seed file
if [ -n "$DUMMY_MODE" ]; then
  SEED=/app/seed/flows-dummy.json
else
  SEED=/app/seed/flows.json
fi

# Init (--force to handle re-deploys with existing volume)
node "$CLI" init --seed "$SEED" --force --db /data/silo.db

# Build worker flags
WORKER_FLAGS="--worker --discipline ${SILO_DISCIPLINE:-engineering} --slots ${SILO_SLOTS:-1} --poll-interval ${SILO_POLL_INTERVAL:-5000}"
if [ -n "$DUMMY_MODE" ]; then
  WORKER_FLAGS="$WORKER_FLAGS --dummy"
fi

exec node "$CLI" serve \
  --http-only \
  --http-host 0.0.0.0 \
  --http-port 3001 \
  --db /data/silo.db \
  ${WORKER_FLAGS}
