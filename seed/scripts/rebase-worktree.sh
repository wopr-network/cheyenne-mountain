#!/bin/sh
WORKTREE="$1"
cd "$WORKTREE" || exit 1
git fetch origin
git rebase origin/main 2>&1
if [ $? -ne 0 ]; then
  git rebase --abort
  echo '{"worktreeReady": false, "error": "rebase conflict"}'
  exit 1
fi
echo '{"worktreeReady": true}'
