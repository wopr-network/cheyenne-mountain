# test-defcon-radar

End-to-end test harness for the defcon + radar pipeline. Runs both services in Docker and lets you verify the full claim/dispatch/signal cycle without touching production.

---

## What This Tests

```
entity created in defcon
  → onEnter provisions a git worktree (provision-worktree CLI)
  → radar slot autonomously claims the entity
  → claude spawns as the architect agent
  → claude writes an implementation spec and signals "Spec ready: WOP-XXXX"
  → gate checks that the spec comment exists on the real Linear issue
  → entity advances to coding state
  → ...
```

With the fake seed data (`WOP-0001` pointing to a synthetic Linear ID), the run exercises every layer through the `spec-posted` gate — which will fail because there's no real Linear issue. That's expected and correct: it proves the full loop executed.

---

## Prerequisites

- Docker Desktop (with WSL2 integration if on Windows)
- A Claude Max account with valid credentials at `~/.claude/.credentials.json`
- (Optional) Real Linear API key + issue key to see a gate pass end-to-end

---

## Setup

```bash
cp .env.example .env
```

Edit `.env`:

```env
DEFCON_ADMIN_TOKEN=changeme-admin      # any string, used for admin API calls
DEFCON_WORKER_TOKEN=changeme-worker    # any string, used by radar to claim/report
LINEAR_API_KEY=lin_api_...             # only needed for real Linear ingestion
```

---

## Run

```bash
docker compose up --build
```

Both images are built from source on first run. Subsequent runs skip the build unless you pass `--build` again.

**defcon** starts first and must pass its healthcheck before radar connects:

```
defcon  | Loaded seed: flows: 1, gates: 4
defcon  | HTTP REST API listening on 0.0.0.0:3001
```

**radar** starts once defcon is healthy:

```
radar  | [radar] Seeded: 1 flows, 1 sources, 1 watches
radar  | [radar] Starting 4 worker slots — role: engineering
```

---

## Create a Test Entity

```bash
curl -X POST http://localhost:3001/api/entities \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer changeme-admin" \
  -d '{
    "flowName": "wopr-changeset",
    "refs": {
      "linear": {
        "id": "aaaabbbb-0000-0000-0000-000000000001",
        "key": "WOP-0001",
        "title": "My test issue",
        "description": "**Repo:** wopr-network/wopr"
      },
      "github": { "repo": "wopr-network/wopr" }
    }
  }'
```

---

## Verify the Pipeline

### 1. Watch defcon events

```bash
docker compose logs -f defcon
```

Healthy sequence:

```
[event] entity.created      → entity entered the pipeline
[event] onEnter.completed   → worktree provisioned, artifacts set
[event] entity.claimed      → radar slot claimed the entity
```

After claude finishes (~5 min for the architect):

```
[event] gate.evaluated      → spec-posted gate ran
[event] gate.failed         → expected with fake Linear ID
```

### 2. Check pipeline status

```bash
curl http://localhost:3001/api/status
```

| Field | What it means |
|-------|---------------|
| `pendingClaims: 1` | onEnter complete, waiting for a slot to claim |
| `activeInvocations: 1` | a slot has claimed and claude is running |
| `activeInvocations: 0, pendingClaims: 1` | gate ran, entity re-queued for retry |

### 3. Confirm claude is running

```bash
docker compose exec radar ps aux | grep claude
```

### 4. Check entity details

```bash
curl http://localhost:3001/api/entities/<entity-id>
```

Look at `artifacts` — after `onEnter.completed` you'll see `worktreePath` and `branch`. If `onEnter_error` appears instead, the hook failed (see Troubleshooting).

---

## Seed Files

### `seed/flows.json` (defcon)

Defines the `wopr-changeset` flow: states, transitions, gates, and onEnter hooks. Loaded by defcon at startup via `node $CLI init --seed`.

The `architecting` state's onEnter command provisions a git worktree using the `provision-worktree` CLI. It pipes output through a tail-scanner to handle pnpm stdout contamination (see the command in `seed/flows.json` for the exact pattern).

### `seed/radar.json` (radar)

Defines the flow mapping, Linear source, and watch rules. Loaded by radar at startup via `node $CLI seed`. Controls which Linear events trigger entity creation.

---

## Troubleshooting

### `onEnter.failed` — `spawnSync git ENOENT`

`git` is missing from the defcon image. Check `Dockerfile.defcon` for `apk add --no-cache git`.

### `spawn claude ENOENT`

`@anthropic-ai/claude-code` is missing from the radar image. Check `Dockerfile.radar`.

### `401 Invalid authentication credentials`

Claude credentials in the container are expired. On the host:

```bash
claude /login
docker compose restart radar
```

The container copies credentials at startup. Restart picks up the fresh token.

### radar logs are empty after startup

Normal. The run loop logs nothing on successful claims. Confirm with:

```bash
docker compose exec radar ps aux          # look for claude process
curl http://localhost:3001/api/status     # look for activeInvocations: 1
```

### Entity stuck with `pendingClaims: 1` for 30+ seconds

Slots sleep 30s after a `check_back` response. If all 4 slots received `check_back` before the entity was ready, they'll all wake up within 30s of the onEnter completing. Wait one full minute before diagnosing further.

### Clean up between runs

```bash
docker compose down -v   # destroys volumes (database state)
docker compose up --build
```

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  docker-compose                                 │
│                                                 │
│  ┌──────────────┐       ┌───────────────────┐   │
│  │   defcon     │       │      radar        │   │
│  │  port 3001   │◄──────│  port 8080        │   │
│  │              │       │                   │   │
│  │  flow engine │       │  4 worker slots   │   │
│  │  SQLite DB   │       │  linear ingestion │   │
│  │  gate runner │       │  claude dispatch  │   │
│  └──────────────┘       └───────────────────┘   │
│         ▲                        │              │
│         │                        ▼              │
│   ./seed/flows.json       ./seed/radar.json     │
│   /data/defcon.db         /data/radar.db        │
└─────────────────────────────────────────────────┘
         ▲                        │
         │                        ▼
   admin API calls           claude binary
   (curl / scripts)          (~/.claude creds)
```

defcon and radar communicate over the internal `pipeline` Docker network. defcon is never exposed to radar's workers directly — radar polls defcon's REST API at `http://defcon:3001`.
