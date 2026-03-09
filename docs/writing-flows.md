# Writing Flows

How to define a flow — the state machine that drives your pipeline.

---

## Anatomy of a Flow

A flow definition is a JSON file with four sections:

```json
{
  "flows": [...],        // Flow metadata (name, concurrency limits)
  "states": [...],       // States with prompts, agent roles, onEnter hooks
  "gates": [...],        // Deterministic checks with optional outcome routing
  "transitions": [...]   // Edges between states, triggered by signals
}
```

### flows

```json
{
  "name": "my-pipeline",
  "description": "What this pipeline does",
  "discipline": "engineering",
  "initialState": "coding",
  "maxConcurrent": 4,
  "maxConcurrentPerRepo": 2,
  "createdBy": "seed:my-pipeline"
}
```

- `initialState` — where entities start when created with this flow
- `maxConcurrent` — build-phase concurrency cap (review/watcher don't count)
- `discipline` — workers declare a discipline; only matching flows are claimed

### states

Each state defines what happens when an entity is there:

```json
{
  "name": "reviewing",
  "flowName": "my-pipeline",
  "agentRole": "my-reviewer",
  "modelTier": "sonnet",
  "mode": "active",
  "onEnter": {
    "command": "scripts/fetch-context.sh {{entity.artifacts.prNumber}}",
    "artifacts": ["prComments", "prDiff"]
  },
  "promptTemplate": "Review this PR...\n\n{{entity.artifacts.prComments}}"
}
```

- `agentRole` — maps to `agents/<role>.md` behavioral contract
- `modelTier` — `opus` (reasoning), `sonnet` (execution), `haiku` (simple tasks)
- `mode` — `active` (claimable by workers) or `passive` (terminal/waiting)
- `onEnter` — runs before the state becomes claimable; output merges into artifacts
- `promptTemplate` — Handlebars template rendered with entity context

### gates

```json
{
  "name": "ci-ready",
  "type": "command",
  "command": "gates/ci-ready.sh {{entity.artifacts.prNumber}} {{entity.refs.github.repo}}",
  "timeoutMs": 1800000,
  "failurePrompt": "CI failed on PR #{{entity.artifacts.prNumber}}.",
  "timeoutPrompt": "CI hasn't finished. Try again.",
  "outcomes": {
    "ready": { "proceed": true },
    "ci_failed": { "toState": "fixing" }
  }
}
```

- `outcomes` — optional routing map. Gate script emits `{"outcome":"ci_failed"}` on last stdout line
- `failurePrompt` — sent to the worker when the gate fails (no matching outcome)
- `timeoutPrompt` — sent when the gate times out

### transitions

```json
{
  "flowName": "my-pipeline",
  "fromState": "coding",
  "toState": "reviewing",
  "trigger": "pr_created",
  "gateName": "ci-ready",
  "priority": 0
}
```

- `trigger` — the signal that activates this transition
- `gateName` — optional gate that must pass before the transition completes
- `priority` — lower = checked first (for multiple transitions from same state)

---

## Design Principles

### The flow is the artifact, not the code

90% of the engineering effort is in the flow definition. Get the prompts right. Get the gates right. Get the context assembly right. The agent is the easy part.

### Every tool call is a flow defect

If an agent makes a tool call to gather context (reading files, fetching comments, checking CI status), the flow failed to provide that context in the prompt. Fix the onEnter hook, not the agent.

### Gates are prompt qualification

A gate doesn't just verify completed work. A gate ensures the next agent's context is complete. The reviewer gate waits for CI + bot comments because the reviewer's prompt needs them. Without the gate, the reviewer either polls (burning tokens) or reviews with incomplete information (wrong answer).

### Gates route, not just verify

If the gate's evidence implies a routing decision an agent would make deterministically, the gate should make that decision. CI red → fixer (skip reviewer). PR merged → done. PR blocked → fixer. Every deterministic agent decision is a candidate for a gate route.

---

## Validation

Run `./validate.sh` before deploying a flow. It checks:
- JSON syntax
- Gate scripts exist at referenced paths
- Agent role files exist
- Transitions reference valid states
- Gate outcomes reference valid states
