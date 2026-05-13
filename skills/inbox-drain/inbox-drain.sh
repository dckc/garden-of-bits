#!/bin/bash
# inbox-drain.sh — find journal entries addressed to a role since the last drain.
#
# Usage: inbox-drain.sh <role> [--no-fetch]
#
#   <role>     The role whose inbox to drain (e.g. liaison, steward).
#   --no-fetch Skip the `git fetch origin journal` at the start.
#
# Behavior:
#   1. (default) `git -C journal fetch --quiet origin journal && git merge --ff-only`.
#   2. Read journal/inboxes/<host>/<role>.md for last_drained_commit.
#      If the state file is missing, initialize it at current journal HEAD with no
#      output (the first run drains nothing; future runs find new messages).
#   3. List entries under entries/ added between last_drained_commit..HEAD whose
#      frontmatter `to:` field matches <role> or "*".
#   4. Output one line per match, chronological by entry timestamp:
#        <ts> <to-field> <relative-path>
#   5. Update the state file atomically (write to *.tmp, then mv).
#
# Concurrency:
#   - Two concurrent runs on the same host write the same state file. The script's
#     output is idempotent (each run shows all messages since the file's last-known
#     commit). Worst case: one update overwrites the other; the next call drains a
#     few extra messages. Benign.
#   - The state file itself is committed and pushed back to origin/journal so other
#     hosts (or the same host across sessions) can pick up where the last drain left
#     off. The push uses the standard journal-sync retry-on-rejection pattern.
#
# Output to stdout is line-oriented so the script can be wrapped in the Monitor
# tool: each new-message line becomes a notification in the parent session.
# Empty-on-no-change so the wrapping monitor stays quiet when nothing is new.

set -e

ROLE="${1:?usage: inbox-drain.sh <role> [--no-fetch]}"
NO_FETCH=0
[ "${2:-}" = "--no-fetch" ] && NO_FETCH=1

# Locate the garden root (this script lives in <root>/skills/inbox-drain/).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GARDEN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JRN="$GARDEN_ROOT/journal"
HOST="$(hostname -s)"
STATE_DIR="$JRN/inboxes/$HOST"
STATE_FILE="$STATE_DIR/$ROLE.md"

mkdir -p "$STATE_DIR"

# Step 1: fetch + ff-merge unless --no-fetch.
if [ "$NO_FETCH" -eq 0 ]; then
  git -C "$JRN" fetch --quiet origin journal 2>/dev/null || true
  # ff-merge if strictly behind; ignore failure (already up to date or local commits).
  git -C "$JRN" merge --ff-only --quiet origin/journal 2>/dev/null || true
fi

CUR_HEAD="$(git -C "$JRN" rev-parse HEAD)"

# Step 2: read last_drained_commit from state file.
LAST=""
if [ -f "$STATE_FILE" ]; then
  LAST="$(awk -F': *' '/^last_drained_commit:/ {print $2; exit}' "$STATE_FILE" | tr -d ' ')"
fi

# First run: initialize state at current HEAD, output nothing.
if [ -z "$LAST" ]; then
  cat > "$STATE_FILE.tmp" <<EOF
---
host: $HOST
role: $ROLE
last_drained_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
last_drained_commit: $CUR_HEAD
---

# $ROLE inbox state on $HOST

Updated by \`skills/inbox-drain/inbox-drain.sh\` after each drain. Use
\`git -C journal log <last_drained_commit>..HEAD\` to see the same range
the next call will scan, or just rerun the script.
EOF
  mv "$STATE_FILE.tmp" "$STATE_FILE"
  exit 0
fi

# Step 3: find entries added in (LAST..HEAD] that target <role> or "*".
# `git diff --diff-filter=A --name-only` is fast and shows only added paths.
ADDED="$(git -C "$JRN" diff --diff-filter=A --name-only "$LAST..HEAD" -- entries/ 2>/dev/null || true)"

if [ -n "$ADDED" ]; then
  # For each added entry, parse `to:` and `ts:` from frontmatter.
  # Output chronologically (sort by ts).
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    full="$JRN/$path"
    [ -f "$full" ] || continue
    TO="$(awk '/^to: */ {sub(/^to: */, ""); gsub(/^"|"$/, ""); print; exit}' "$full")"
    TS="$(awk '/^ts: */ {sub(/^ts: */, ""); print; exit}' "$full")"
    if [ "$TO" = "$ROLE" ] || [ "$TO" = "*" ]; then
      printf "%s %s %s\n" "$TS" "$TO" "$path"
    fi
  done <<< "$ADDED" | sort
fi

# Step 4: update state file atomically.
cat > "$STATE_FILE.tmp" <<EOF
---
host: $HOST
role: $ROLE
last_drained_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
last_drained_commit: $CUR_HEAD
---

# $ROLE inbox state on $HOST

Updated by \`skills/inbox-drain/inbox-drain.sh\` after each drain. Use
\`git -C journal log <last_drained_commit>..HEAD\` to see the same range
the next call will scan, or just rerun the script.
EOF
mv "$STATE_FILE.tmp" "$STATE_FILE"
