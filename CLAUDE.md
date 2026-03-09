# Bunker — Docker Compose test harness for defcon+radar+norad

## Gotchas
- **PR timestamp filtering**: `PR.updated_at` advances on ANY activity (comments, labels, title edits), not just pushes. Use the head commit's `committer.date` via `repos/{owner}/{repo}/commits/{sha}` for actual push time.
- **Signal format**: Fixer agents must emit bare signal keywords (e.g. `cant_resolve` on its own line) matching `parse-signal.ts` regex `/^cant_resolve\r?$/` — never prose like "Can't resolve: reason".
