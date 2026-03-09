#!/usr/bin/env bash
# validate.sh — Check flow definition integrity before running.
# Verifies that all referenced gates, scripts, and agent roles exist.

set -e

ERRORS=0
WARNINGS=0

err() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "WARN:  $1"; WARNINGS=$((WARNINGS + 1)); }
ok() { echo "OK:    $1"; }

echo "=== Validating SILO flow definitions ==="
echo ""

# Check each flow file
for FLOW_FILE in flows/*.json; do
  [ -f "$FLOW_FILE" ] || continue
  FLOW_NAME=$(basename "$FLOW_FILE" .json)
  echo "--- Flow: $FLOW_NAME ($FLOW_FILE) ---"

  # Validate JSON syntax
  if ! node -e "JSON.parse(require('fs').readFileSync('$FLOW_FILE','utf8'))" 2>/dev/null; then
    err "$FLOW_FILE: invalid JSON"
    continue
  fi
  ok "JSON syntax valid"

  # Extract gate commands and check scripts exist
  GATE_COMMANDS=$(node -e "
    const f = JSON.parse(require('fs').readFileSync('$FLOW_FILE','utf8'));
    (f.gates || []).forEach(g => {
      if (g.command) {
        const script = g.command.split(' ')[0];
        console.log(g.name + '|' + script);
      }
    });
  " 2>/dev/null)

  while IFS='|' read -r GATE_NAME SCRIPT; do
    [ -z "$GATE_NAME" ] && continue
    if [ -f "$SCRIPT" ]; then
      ok "gate '$GATE_NAME' → $SCRIPT exists"
    else
      err "gate '$GATE_NAME' references $SCRIPT but file not found"
    fi
  done <<< "$GATE_COMMANDS"

  # Extract agent roles and check .md files exist
  ROLES=$(node -e "
    const f = JSON.parse(require('fs').readFileSync('$FLOW_FILE','utf8'));
    (f.states || []).forEach(s => {
      if (s.agentRole) console.log(s.name + '|' + s.agentRole);
    });
  " 2>/dev/null)

  while IFS='|' read -r STATE_NAME ROLE; do
    [ -z "$ROLE" ] && continue
    if [ -f "agents/$ROLE.md" ]; then
      ok "state '$STATE_NAME' agent '$ROLE' → agents/$ROLE.md exists"
    else
      warn "state '$STATE_NAME' agent '$ROLE' → agents/$ROLE.md not found (will use ~/.claude/agents/)"
    fi
  done <<< "$ROLES"

  # Check transitions reference valid states
  TRANSITION_ERRORS=$(node -e "
    const f = JSON.parse(require('fs').readFileSync('$FLOW_FILE','utf8'));
    const stateNames = new Set((f.states || []).map(s => s.name));
    const gateNames = new Set((f.gates || []).map(g => g.name));
    let errors = 0;
    (f.transitions || []).forEach(t => {
      if (!stateNames.has(t.fromState)) { console.error('ERROR: transition from unknown state: ' + t.fromState); errors++; }
      if (!stateNames.has(t.toState)) { console.error('ERROR: transition to unknown state: ' + t.toState); errors++; }
      if (t.gateName && !gateNames.has(t.gateName)) { console.error('ERROR: transition references unknown gate: ' + t.gateName); errors++; }
    });
    // Check outcome toState references
    (f.gates || []).forEach(g => {
      if (g.outcomes) {
        Object.entries(g.outcomes).forEach(([name, o]) => {
          if (o.toState && !stateNames.has(o.toState)) { console.error('ERROR: gate ' + g.name + ' outcome ' + name + ' references unknown state: ' + o.toState); errors++; }
        });
      }
    });
    console.log(errors);
  " 2>&1)

  # Last line is the error count, preceding lines are error messages
  TRANSITION_ERROR_COUNT=$(echo "$TRANSITION_ERRORS" | tail -1)
  if [ "$TRANSITION_ERROR_COUNT" -gt 0 ] 2>/dev/null; then
    echo "$TRANSITION_ERRORS" | head -n -1
    ERRORS=$((ERRORS + TRANSITION_ERROR_COUNT))
  fi

  echo ""
done

# Summary
echo "=== Validation complete ==="
if [ "$ERRORS" -gt 0 ]; then
  echo "$ERRORS error(s), $WARNINGS warning(s)"
  exit 1
else
  echo "0 errors, $WARNINGS warning(s)"
  exit 0
fi
