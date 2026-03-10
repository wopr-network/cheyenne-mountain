# Phase 1: Repo Renames — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename repos so defcon becomes silo and current silo becomes cheyenne-mountain, freeing up the architecture for the merge.

**Architecture:** GitHub renames with redirect support, local directory moves, reference updates across all repos and memory files.

**Tech Stack:** GitHub CLI (`gh`), git, bash

---

## Chunk 1: GitHub Renames and Local Moves

### Task 1: Rename wopr-network/silo → wopr-network/cheyenne-mountain

GitHub must process this rename first to free the `silo` name for defcon.

**Files:**
- Modify: GitHub repo settings (via `gh` CLI)
- Modify: `~/silo/package.json` (if it has one)
- Modify: `~/silo/CLAUDE.md`
- Modify: `~/silo/README.md`

- [ ] **Step 1: Rename the repo on GitHub**

```bash
gh repo rename cheyenne-mountain --repo wopr-network/silo --yes
```

Expected: Repo renamed, GitHub creates redirect from old URL.

- [ ] **Step 2: Move the local directory**

```bash
mv ~/silo ~/cheyenne-mountain
```

- [ ] **Step 3: Update the git remote**

```bash
cd ~/cheyenne-mountain
git remote set-url origin https://github.com/wopr-network/cheyenne-mountain.git
git remote -v
```

Expected: Both fetch and push point to `wopr-network/cheyenne-mountain.git`.

- [ ] **Step 4: Update CLAUDE.md header**

Change the header from `SILO` to `Cheyenne Mountain` and update the description to reflect it's the WOPR deployment, not the engine.

- [ ] **Step 5: Update README.md header**

Change title and description. This is now the WOPR-specific deployment repo, not the test harness.

- [ ] **Step 6: Commit**

```bash
cd ~/cheyenne-mountain
git add -A
git commit -m "docs: rename silo → cheyenne-mountain"
git push
```

---

### Task 2: Rename wopr-network/defcon → wopr-network/silo

Now that the `silo` name is free on GitHub.

**Files:**
- Modify: GitHub repo settings (via `gh` CLI)
- Modify: `~/defcon/package.json` — change `name` to `@wopr-network/silo`
- Modify: `~/defcon/CLAUDE.md`
- Modify: `~/defcon/README.md`

- [ ] **Step 1: Rename the repo on GitHub**

```bash
gh repo rename silo --repo wopr-network/defcon --yes
```

Expected: Repo renamed, GitHub creates redirect from old URL.

- [ ] **Step 2: Move the local directory**

```bash
mv ~/defcon ~/silo
```

- [ ] **Step 3: Update the git remote**

```bash
cd ~/silo
git remote set-url origin https://github.com/wopr-network/silo.git
git remote -v
```

Expected: Both fetch and push point to `wopr-network/silo.git`.

- [ ] **Step 4: Update package.json name**

Change `"name": "@wopr-network/defcon"` to `"name": "@wopr-network/silo"`.

Do NOT publish yet — that happens after radar merge in Phase 2.

- [ ] **Step 5: Update CLAUDE.md**

Change header and description. This is now the generic pipeline engine.

- [ ] **Step 6: Commit**

```bash
cd ~/silo
git add -A
git commit -m "docs: rename defcon → silo"
git push
```

---

## Chunk 2: Reference Updates

### Task 3: Update cheyenne-mountain references to point at new silo

**Files:**
- Modify: `~/cheyenne-mountain/docker-compose.yml` — any image names or references
- Modify: `~/cheyenne-mountain/Dockerfile.defcon` — rename to `Dockerfile.silo`, update npm package name
- Modify: `~/cheyenne-mountain/seed/flows.json` — CLI path references if they use `@wopr-network/defcon`

- [ ] **Step 1: Rename Dockerfile.defcon → Dockerfile.silo**

```bash
cd ~/cheyenne-mountain
mv Dockerfile.defcon Dockerfile.silo
```

- [ ] **Step 2: Update Dockerfile.silo**

Change `npm install -g @wopr-network/defcon@latest` to `npm install -g @wopr-network/silo@latest`.
Update `ENV CLI` path from `defcon` to `silo`.

Note: This will break until the silo npm package is published. That's expected — don't publish yet.

- [ ] **Step 3: Update docker-compose.yml**

Change service name `defcon` references and Dockerfile references.
Update `Dockerfile.defcon` → `Dockerfile.silo`.

- [ ] **Step 4: Update seed/flows.json CLI paths**

Any onEnter commands referencing `@wopr-network/defcon` path → `@wopr-network/silo`.

- [ ] **Step 5: Commit**

```bash
cd ~/cheyenne-mountain
git add -A
git commit -m "refactor: update references from defcon to silo"
git push
```

---

### Task 4: Update memory and cross-repo references

**Files:**
- Modify: `~/.claude/projects/-home-tsavo/memory/MEMORY.md`
- Modify: `~/.claude/projects/-home-tsavo/memory/defcon-radar.md`
- Modify: `~/.claude/projects/-home-tsavo-silo/memory/` (will need new project path)
- Modify: `~/norad/` — any references to defcon URL or package name
- Modify: `~/radar/` — any references to defcon package name (before radar gets merged in Phase 2)

- [ ] **Step 1: Update MEMORY.md repo locations**

Update the WOPR Repo Locations section:
- `~/defcon` → `~/silo` (wopr-network/silo)
- `~/silo` → `~/cheyenne-mountain` (wopr-network/cheyenne-mountain)
- Add note: `~/silo` is now the engine (formerly defcon), `~/cheyenne-mountain` is the WOPR deployment (formerly silo/bunker)

- [ ] **Step 2: Update defcon-radar.md**

Rename file to `silo-engine.md`. Update all `~/defcon` references to `~/silo`. Update architecture section to reflect the merge design.

- [ ] **Step 3: Update radar references**

In `~/radar/package.json`, note that `@wopr-network/defcon` dependency will become `@wopr-network/silo`. Don't change yet — this happens in Phase 2 merge.

- [ ] **Step 4: Update norad references**

Check `~/norad` for any hardcoded references to `defcon` service name or `@wopr-network/defcon` package. Note changes needed for Phase 2.

- [ ] **Step 5: Commit memory changes**

No git commit needed — memory files aren't in a repo.

---

## Pre-Conditions

- GitHub CLI authenticated with repo admin permissions on wopr-network org
- No active PRs or CI runs on either repo that would break with a rename
- Docker stack is down (confirmed earlier)

## Post-Conditions

- `wopr-network/silo` is the engine repo (formerly defcon)
- `wopr-network/cheyenne-mountain` is the WOPR deployment repo (formerly silo)
- `~/silo` points to the engine
- `~/cheyenne-mountain` points to the deployment
- GitHub redirects handle old URLs
- Memory files updated
- Nothing is published to npm yet — that waits for Phase 2
