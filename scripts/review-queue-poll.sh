#!/bin/bash
# review-queue-poll.sh — long-lived poll daemon for kriskowal's pending
# review-request queue across all repos visible to the bot's gh auth.
#
# Usage: review-queue-poll.sh <state-dir> <cadence-seconds>
#
# Polls `gh search prs --review-requested=kriskowal --state=open` on the
# given cadence. Atomically writes the canonical set to <state-dir>/current.json,
# rolls the previous snapshot to <state-dir>/prev.json before each write, and
# emits one stdout line per diff:
#
#   [HH:MM:SS] ADD <owner>/<name>#<n> draft=<bool> updated=<iso> '<title>'
#   [HH:MM:SS] REMOVE <owner>/<name>#<n>
#   [HH:MM:SS] unchanged n=<count>
#
# The LLM-driven review-queue role only wakes when the steward sees a
# non-`unchanged` line in the log since the prior cycle.
#
# Search-rate-limit budget is 30/min for the authenticated user; default
# cadence of 120s burns 30/hr, comfortable.

set -uo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <state-dir> <cadence-seconds>" >&2
  exit 64
fi

STATE=$1
CADENCE=$2
mkdir -p "$STATE"

trap 'echo "[$(date -u +%H:%M:%S)] daemon stopping pid=$$"; exit 0' INT TERM

echo "[$(date -u +%H:%M:%S)] review-queue daemon starting state=$STATE cadence=${CADENCE}s pid=$$"

while true; do
  TMP_OUT=$(mktemp)
  TMP_ERR=$(mktemp)

  if gh search prs --review-requested=kriskowal --state=open --limit=100 \
       --json number,repository,title,url,author,isDraft,updatedAt \
       > "$TMP_OUT" 2> "$TMP_ERR"; then

    python3 - "$TMP_OUT" "$STATE" <<'PY'
import json, sys, os, datetime, shutil
src, state = sys.argv[1], sys.argv[2]
raw = json.load(open(src))
canon = []
for row in raw:
    repo_obj = row.get('repository') or {}
    repo = repo_obj.get('nameWithOwner') or f"{repo_obj.get('owner','?')}/{repo_obj.get('name','?')}"
    canon.append({
        "repo": repo,
        "number": row.get('number'),
        "title": row.get('title',''),
        "url": row.get('url',''),
        "isDraft": bool(row.get('isDraft', False)),
        "updatedAt": row.get('updatedAt',''),
        "author": (row.get('author') or {}).get('login','?'),
        "requestedAt": None,
    })
canon.sort(key=lambda r: (r['repo'], r['number']))
cur_path = os.path.join(state, 'current.json')
prev_path = os.path.join(state, 'prev.json')
prev = []
if os.path.exists(cur_path):
    try:
        prev = json.load(open(cur_path))
    except Exception:
        prev = []
def key(r): return (r['repo'], r['number'])
prev_keys = {key(r): r for r in prev}
cur_keys  = {key(r): r for r in canon}
added   = [cur_keys[k] for k in cur_keys if k not in prev_keys]
removed = [prev_keys[k] for k in prev_keys if k not in cur_keys]
ts = datetime.datetime.utcnow().strftime('%H:%M:%S')
if added or removed:
    for r in added:
        title = r['title'].replace("'", "\\'")
        if len(title) > 80: title = title[:77] + '...'
        print(f"[{ts}] ADD {r['repo']}#{r['number']} draft={str(r['isDraft']).lower()} updated={r['updatedAt']} '{title}'", flush=True)
    for r in removed:
        print(f"[{ts}] REMOVE {r['repo']}#{r['number']}", flush=True)
else:
    print(f"[{ts}] unchanged n={len(canon)}", flush=True)
# Roll prev, then atomic write current.
if os.path.exists(cur_path):
    shutil.copyfile(cur_path, prev_path + '.tmp')
    os.replace(prev_path + '.tmp', prev_path)
tmp = cur_path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(canon, f, indent=2)
    f.write('\n')
os.replace(tmp, cur_path)
PY

  else
    echo "[$(date -u +%H:%M:%S)] gh search failed:" >&2
    head -c 500 "$TMP_ERR" >&2
    echo "" >&2
    # If auth failed (401-ish), gh prints an explicit message; back off long.
    if grep -q -i 'authentication\|not authenticated\|HTTP 401' "$TMP_ERR"; then
      echo "[$(date -u +%H:%M:%S)] auth failed; daemon stopping" >&2
      rm -f "$TMP_OUT" "$TMP_ERR"
      exit 1
    fi
    # Otherwise back off 60s and retry.
    sleep 60
  fi

  rm -f "$TMP_OUT" "$TMP_ERR"
  sleep "$CADENCE"
done
