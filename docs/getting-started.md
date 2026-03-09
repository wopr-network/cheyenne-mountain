# Getting Started with the SILO

The SILO is the reference implementation of the agentic engineering pipeline. It contains everything needed to run DEFCON + RADAR + NORAD as a complete automated software delivery system.

> **The SILO and NUKE are what you fork.** You don't fork DEFCON (that's the engine). You don't fork RADAR (that's the dispatcher). You fork the SILO (flow definitions, gates, agents) and the NUKE (agent containers) and customize them for your project.

---

## What's Inside

```
seed/                 — Everything DEFCON seeds on startup (mounted at /app/seed)
  flows.json          — The production flow definition (states, prompts, gates, transitions)
  flows-dummy.json    — Minimal scaffold for testing (no gates/onEnter)
  radar.json          — RADAR configuration (sources, watches)
  gates/              — Gate scripts (deterministic shell checks)
  scripts/            — onEnter hooks (context assembly)

flows/                — Reference copies for browsing (not mounted into containers)
agents/               — Agent role files (behavioral contracts)
docker-compose.yml    — Full stack: DEFCON + RADAR + NORAD
validate.sh           — Check flow integrity before running
```

> **Note:** The `seed/` directory is what DEFCON actually loads at startup. The top-level `flows/`, `gates/`, `scripts/`, and `agents/` directories are reference copies for browsing and validation. When customizing flows, edit the files in `seed/` — those are what the running stack uses.

### Flows

Each `.json` file in `flows/` defines a complete pipeline:

- **wopr-changeset.json** — Full pipeline: architect → code → review → fix → merge. For feature work and non-trivial changes.
- **wopr-hotfix.json** — Fast-track: code → review → fix → merge. Skips the architect for trivial fixes.

The flow definition is the primary engineering artifact. It contains the prompt templates, gate configurations, onEnter hooks, and transition rules that govern every agent invocation.

### Gates

Shell scripts in `gates/` that verify work at transition boundaries:

| Gate | What it checks | Outcomes |
|------|---------------|----------|
| `spec-posted.sh` | Architect posted spec to Linear | pass / fail |
| `review-bots-ready.sh` | CI green + review bots posted | pass / fail |
| `merge-queue.sh` | PR merged successfully | merged / blocked / closed |

Gates cost $0.00. They replace agent invocations that would cost $0.03-$0.50.

### Scripts

onEnter hooks in `scripts/` that assemble context before agents fire:

| Script | What it assembles | Used by |
|--------|------------------|---------|
| `fetch-spec.js` | Architect spec from Linear | coding state |
| `fetch-pr-context.js` | PR comments + diff from GitHub | reviewing, fixing states |

Every piece of context the agent needs should be assembled by an onEnter hook. If an agent makes a tool call to gather context, that's a flow design defect.

### Agents

Markdown files in `agents/` that define behavioral contracts:

| Agent | Role | Key constraint |
|-------|------|---------------|
| `wopr-architect.md` | Write specs, not code | Read-only. No git operations. |
| `wopr-coder.md` | Implement the spec | Spec is in the prompt. Don't fetch it. |
| `wopr-reviewer.md` | Render verdict | Context is in the prompt. Read it. |
| `wopr-fixer.md` | Fix findings | Findings are in the prompt. Don't fetch them. |

---

## Running

### Prerequisites

- Docker and Docker Compose
- GitHub CLI (`gh`) authenticated
- Linear API key
- Anthropic API key (for Claude agents)

### Setup

```bash
# Clone the SILO
git clone https://github.com/wopr-network/silo.git silo
cd silo

# Copy and configure environment
cp .env.example .env
# Edit .env with your API keys

# Validate flow definitions
./validate.sh

# Start the stack
docker compose up -d
```

### Creating an Entity

```bash
# Create an entity to process through the pipeline
curl -X POST http://localhost:3001/api/entities \
  -H "Content-Type: application/json" \
  -d '{
    "flow": "wopr-changeset",
    "refs": {
      "linear": {
        "id": "<LINEAR_ISSUE_UUID>",
        "key": "WOP-123",
        "title": "Add session management",
        "description": "..."
      },
      "github": {
        "repo": "wopr-network/wopr"
      }
    }
  }'
```

RADAR will claim the entity, dispatch agents, and drive it through the flow.

### Watching

Open NORAD at `http://localhost:3000` to watch entities flow through the pipeline in real time.

---

## Customizing

### Adding a New Flow

1. Create `flows/my-flow.json` with states, gates, transitions
2. Add gate scripts to `gates/`
3. Add agent role files to `agents/`
4. Run `./validate.sh` to check integrity
5. Restart the stack: `docker compose restart defcon`

### Writing Gate Scripts

Gate scripts must:
1. Exit 0 for pass, exit 1 for fail
2. Write diagnostic output to stderr (for logs)
3. Optionally emit JSON on the last stdout line for outcome routing:
   ```json
   {"outcome": "ci_failed", "message": "3 checks failing on PR #456"}
   ```

See `gates/merge-queue.sh` for an example of outcome routing.

### Writing onEnter Hooks

onEnter scripts must:
1. Output a single JSON object on stdout
2. The JSON keys must match the `artifacts` array in the state definition
3. Write diagnostic output to stderr

See `scripts/fetch-spec.js` for an example.

---

## The NUKE — Agent Containers

The SILO defines WHAT happens (flows, gates, prompts). The [NUKE](https://github.com/wopr-network/nuke) defines HOW agents run — the Docker containers that execute each invocation.

The NUKE repo contains:
- `packages/worker-runtime/` — HTTP server that receives dispatch requests from RADAR, streams SSE events back, and parses signals from agent output
- `workers/coder/Dockerfile` — container for the coder discipline (git, gh CLI, pnpm)
- `workers/devops/Dockerfile` — container for the devops discipline (git, curl)

Each discipline gets its own Dockerfile with project-specific tooling. A Python shop adds `pip`, `pytest`, `ruff`. A Rust shop adds `cargo`, `clippy`. The runtime is shared — the tooling is yours.

RADAR POSTs `{prompt, modelTier}` to the nuke's `/dispatch` endpoint. The nuke streams back SSE events: `session`, `tool_use`, `text`, and finally `result` with the parsed signal and artifacts. The nuke dies after each invocation.

**Fork the NUKE** to customize what's installed in your agent containers.

---

## Cross-References

- [DEFCON](https://github.com/wopr-network/defcon) — the state machine engine
- [RADAR](https://github.com/wopr-network/radar) — detection and dispatch
- [NUKE](https://github.com/wopr-network/nuke) — agent containers
- [NORAD](https://github.com/wopr-network/norad) — the command center dashboard
- [The Thesis](https://github.com/wopr-network/defcon/blob/main/docs/method/manifesto/the-thesis.md) — why this exists
