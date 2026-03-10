# Silo Merge Design — Unified Pipeline Engine

## Summary

Merge defcon (flow engine) and radar (worker pool) into a single project called **silo**. Silo becomes a generic, WOPR-agnostic pipeline engine published as `@wopr-network/silo`. WOPR-specific configuration (flows, gates, agents, hooks) moves to a separate deployment repo called **cheyenne-mountain**. Norad (dashboard) remains a separate repo/deploy, querying silo's REST API.

## Architecture

### Silo (the engine)

One process. One SQLite database. One npm package.

**Modules:**

- **Engine** — `IFlowEngine` interface. State machine, entity lifecycle, transitions, gate evaluation, invocation building. From defcon.
- **Worker Pool** — Run loop, slot management. Calls `IFlowEngine` directly (no HTTP). From radar.
- **Dispatchers** — `INukeDispatcher` interface. Ships with `ClaudeCodeDispatcher`, `SdkDispatcher`, `NukeDispatcher`, `DummyDispatcher`. From radar.
- **Ingestion** — Source adapters, webhook handling, event-to-entity mapping. From radar.
- **REST API** — Thin adapter over `IFlowEngine` for external consumers (norad, admin). Claim, report, entity CRUD, flow management, activity feed, SSE events.
- **Database** — One SQLite DB. Merged schema from defcon + radar via Drizzle.
- **CLI** — `silo run`, `silo seed`, `silo doctor`. Combined from both CLIs.

**Extension points (for downstream deployments):**

- Config file — flows, states, transitions, gate definitions, model tiers, concurrency limits.
- Gates directory — shell scripts. Registered TypeScript functions checked first, script fallback.
- Agents directory — Handlebars `.md` templates. Rendered by silo's invocation builder.
- Hooks directory — onEnter/onExit shell scripts or registered functions.
- Dispatcher selection — config chooses which dispatcher to use.

### Cheyenne Mountain (the WOPR deployment)

Depends on `@wopr-network/silo`. Contains all WOPR-specific config:

```
cheyenne-mountain/
├── package.json          # depends on @wopr-network/silo
├── silo.config.json      # flows, gates, hooks, agent roles
├── gates/                # wopr-specific gate scripts
├── agents/               # wopr-specific agent .md files
├── hooks/                # onEnter/onExit scripts
├── docker-compose.yml    # production deployment
└── seed/                 # initial flow + entity data
```

### Norad (the dashboard)

Separate repo. Separate deploy. Queries silo's REST API. Next.js.

### Ecosystem

```
┌─────────────────────────┐
│   Cheyenne Mountain     │  WOPR-specific deployment
│   depends on silo       │  flows, gates, agents, hooks
│   Dockerfile + config   │
└──────────┬──────────────┘
           │ imports
┌──────────▼──────────────┐
│   Silo                  │  Generic engine
│   @wopr-network/silo    │  IFlowEngine + worker pool
│   REST API on one port  │  + dispatchers + ingestion
└──────────┬──────────────┘
           │ REST API
┌──────────▼──────────────┐
│   Norad                 │  Dashboard UI
│   Separate repo/deploy  │  Queries silo's REST API
│   Next.js               │
└─────────────────────────┘
```

## Key Design Decisions

1. **IFlowEngine interface** — Engine implements it. Run loop calls it directly. REST API is a thin adapter over it. No internal HTTP.
2. **One SQLite database** — Merged schema from defcon.db and radar.db.
3. **Gates/hooks: dual path** — Registered TypeScript functions first, shell script fallback. Both available.
4. **Dispatcher already pluggable** — `INukeDispatcher` interface from radar carries forward unchanged.
5. **Template rendering in silo** — Handlebars + invocation builder stays in the engine. Cheyenne Mountain provides the templates.
6. **DummyDispatcher for testing** — Silo ships it. Cheyenne Mountain flips a flag to run full flow without tokens.

## Repo Operations

1. Rename `wopr-network/silo` → `wopr-network/cheyenne-mountain`
2. Rename `wopr-network/defcon` → `wopr-network/silo`
3. Merge `wopr-network/radar` into new silo
4. Kill `@wopr-network/radar` npm package
5. Kill `@wopr-network/defcon` npm package, publish as `@wopr-network/silo`

## What Silo Does NOT Know

- WOPR, Linear, GitHub, any specific repo
- `wopr-changeset` flow or any flow definition
- `spec-posted`, `review-bots-ready`, `merge-queue` or any gate
- Architect, coder, reviewer agent roles
- Any onEnter hook implementation
