#!/bin/sh
WORKTREE="$1"
cd "$WORKTREE" || exit 1
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
DEFAULT_BRANCH=${DEFAULT_BRANCH:-main}
if ! git fetch origin >/dev/null 2>&1; then
  echo '{"worktreeReady":false,"error":"fetch failed"}'
  exit 1
fi
if ! git rebase "origin/$DEFAULT_BRANCH" >/dev/null 2>&1; then
  git rebase --abort
  echo '{"worktreeReady": false, "error": "rebase conflict"}'
  exit 1
fi
echo '{"worktreeReady": true}'
