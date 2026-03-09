#!/bin/sh
# spec-posted.sh <LINEAR_ISSUE_ID>
# Exits 0 if a spec comment (containing "## Implementation Spec") exists on the issue.
# Exits 1 if not found.

ISSUE_ID="${1:-}"
if [ -z "$ISSUE_ID" ]; then
  echo "Usage: spec-posted.sh <LINEAR_ISSUE_ID>" >&2
  exit 1
fi

if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "LINEAR_API_KEY not set" >&2
  exit 1
fi

QUERY="{\"query\":\"query(\$id: String!) { issue(id: \$id) { comments { nodes { body } } } }\",\"variables\":{\"id\":\"$ISSUE_ID\"}}"

RESPONSE=$(wget -q -O - \
  --header="Authorization: $LINEAR_API_KEY" \
  --header="Content-Type: application/json" \
  --post-data="$QUERY" \
  https://api.linear.app/graphql 2>/dev/null)

if echo "$RESPONSE" | grep -q "## Implementation Spec"; then
  echo "Spec found on issue $ISSUE_ID"
  exit 0
else
  echo "No spec comment found on issue $ISSUE_ID" >&2
  exit 1
fi
