#!/bin/bash
# dispatch-prepare.sh — create a per-dispatch worktree triple.
#
# Usage:
#   dispatch-prepare.sh <role> <purpose-slug> [<owner>/<repo> <branch>]
#
# Prints the absolute path of the dispatch root on stdout. The orchestrator
# (liaison or steward) passes that path into the subagent's dispatch prompt
# and tears the root down via `dispatch-teardown.sh` once the subagent
# returns.
#
# Layout:
#   dispatches/<role>--<purpose>--<UTC-YYYYMMDD-HHMMSS>--<short-id>/
#     garden/    detached worktree of the garden's `main` branch
#     journal/   detached worktree of the garden's `journal` branch
#     project/   (only when a project repo is named) detached worktree of
#                worktrees/<owner>-<repo>.git at <branch>
#
# All three worktrees are checked out in detached-HEAD so a subagent can
# `git fetch origin <branch>`, rebase, and `git push origin HEAD:<branch>`
# without competing for branch ownership with the orchestrator's checkout.

set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -eq 3 ]; then
  echo "usage: $0 <role> <purpose-slug> [<owner>/<repo> <branch>]" >&2
  exit 64
fi

ROLE=$1
PURPOSE=$2
GARDEN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

TS=$(date -u +%Y%m%d-%H%M%S)
ID=$(openssl rand -hex 3)
NAME="${ROLE}--${PURPOSE}--${TS}--${ID}"
ROOT="${GARDEN_ROOT}/dispatches/${NAME}"

mkdir -p "$ROOT"

# Garden + journal worktrees both come from the garden repo's admin tree
# at $GARDEN_ROOT/.git. `git worktree add --detach <path> <ref>` puts the
# new worktree at the named ref in detached-HEAD state.
git -C "$GARDEN_ROOT" worktree add --detach "$ROOT/garden"  main    >/dev/null
git -C "$GARDEN_ROOT" worktree add --detach "$ROOT/journal" journal >/dev/null

if [ "$#" -ge 4 ]; then
  REPO=$3
  BRANCH=$4
  OWNER=${REPO%/*}
  NAME_=${REPO#*/}
  BARE="${GARDEN_ROOT}/worktrees/${OWNER}-${NAME_}.git"
  if [ ! -d "$BARE" ]; then
    echo "dispatch-prepare: bare clone not found at $BARE" >&2
    echo "                  clone first via: git clone --bare https://github.com/${REPO}.git $BARE" >&2
    # roll back partial state
    git -C "$GARDEN_ROOT" worktree remove --force "$ROOT/garden"  >/dev/null 2>&1 || true
    git -C "$GARDEN_ROOT" worktree remove --force "$ROOT/journal" >/dev/null 2>&1 || true
    rmdir "$ROOT" 2>/dev/null || rm -rf "$ROOT"
    exit 1
  fi
  git --git-dir="$BARE" worktree add --detach "$ROOT/project" "$BRANCH" >/dev/null
fi

echo "$ROOT"
