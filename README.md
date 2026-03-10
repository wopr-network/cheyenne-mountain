# Cheyenne Mountain

WOPR deployment config for **silo** — the unified flow engine + worker pool.

---

## What This Tests

```
entity created in silo
  → silo slot autonomously claims the entity
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
SILO_ADMIN_TOKEN=changeme-admin      # any string, used for admin API calls
SILO_WORKER_TOKEN=changeme-worker    # any string, used by silo workers to claim/report
LINEAR_API_KEY=lin_api_...           # only needed for real Linear ingestion
```

---

## Run

```bash
docker compose up --build
```

**silo** starts and must pass its healthcheck before norad connects:

```
silo  | Loaded seed: flows: 1, gates: 4
silo  | HTTP REST API listening on 0.0.0.0:3001
```

**norad** (UI) starts once silo is healthy:

```
norad | ▲ Next.js ready on http://localhost:3000
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

### 1. Watch silo events

```bash
docker compose logs -f silo
```

Healthy sequence:

```
[event] entity.created      → entity entered the pipeline
[event] entity.claimed      → silo slot claimed the entity
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
| `pendingClaims: 1` | waiting for a slot to claim |
| `activeInvocations: 1` | a slot has claimed and claude is running |
| `activeInvocations: 0, pendingClaims: 1` | gate ran, entity re-queued for retry |

### 3. Check entity details

```bash
curl http://localhost:3001/api/entities/<entity-id>
```

---

## Seed Files

### `seed/flows.json`

Defines the `wopr-changeset` flow: states, transitions, gates, and onEnter hooks. Loaded by silo at startup via `silo init --seed`.

### `seed/radar.json`

Defines the flow mapping, Linear source, and watch rules. Controls which Linear events trigger entity creation.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  docker-compose                                 │
│                                                 │
│  ┌──────────────────────────────────────────┐   │
│  │              silo                        │   │
│  │  port 3001                               │   │
│  │                                          │   │
│  │  flow engine + worker pool (unified)     │   │
│  │  SQLite DB    (/data/silo.db)            │   │
│  │  gate runner  + claude dispatch          │   │
│  │  linear ingestion                        │   │
│  └──────────────────────────────────────────┘   │
│         ▲                                       │
│         │                                       │
│   ./seed/flows.json                             │
│   ./seed/radar.json                             │
└─────────────────────────────────────────────────┘
         ▲                        │
         │                        ▼
   admin API calls           claude binary
   (curl / norad UI)        (~/.claude creds)
```

---

## Troubleshooting

### `spawn claude ENOENT`

`@anthropic-ai/claude-code` is missing from the silo image. Check `Dockerfile.silo`.

### `401 Invalid authentication credentials`

Claude credentials in the container are expired. On the host:

```bash
claude /login
docker compose restart silo
```

### Entity stuck with `pendingClaims: 1` for 30+ seconds

Slots sleep 30s after a `check_back` response. Wait one full minute before diagnosing further.

### Clean up between runs

```bash
docker compose down -v   # destroys volumes (database state)
docker compose up --build
```
