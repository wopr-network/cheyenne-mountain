# Bunker — Docker Compose test harness for defcon+radar+norad

## Gotchas
- **PR timestamp filtering**: `PR.updated_at` advances on ANY activity (comments, labels, title edits), not just pushes. Use the head commit's `committer.date` via `repos/{owner}/{repo}/commits/{sha}` for actual push time.
- **Signal format**: Fixer agents must emit bare signal keywords (e.g. `cant_resolve` on its own line) matching `parse-signal.ts` regex `/^cant_resolve\r?$/` — never prose like "Can't resolve: reason".
- Co-Authored-By in commits must match the agent's modelTier: haiku agents use "Claude Haiku 4.5 <noreply@anthropic.com>", sonnet uses "Claude Sonnet 4.6 <noreply@anthropic.com>".
- Agent workflows that update CLAUDE.md must handle "create if not exists" — on fresh repos the file won't exist, causing cant_learn signals and pipeline stalls.
- Signal tokens in agent .md files (e.g. `docs_pr_created`) must exactly match the transition triggers in flows.json (e.g. `docs_ready`) — mismatches cause silent gate failures.
- Docker volume mounts for agent .md files must use repo-relative paths (`./agents:/claude-agents:ro`), never host-user paths (`~/.claude/agents`) — the latter breaks in CI and other machines.
