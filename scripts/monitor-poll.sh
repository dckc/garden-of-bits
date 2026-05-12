#!/bin/bash
# monitor-poll.sh — long-lived poll daemon for one GitHub repo's events feed.
#
# Usage: monitor-poll.sh <owner>/<name> <worktree-path> <cadence-seconds>
#
# Polls https://api.github.com/repos/<owner>/<name>/events with conditional
# GETs (ETag + If-None-Match). 304 responses cost nothing against the
# primary REST rate limit, so the steady state is free. On a 200 with new
# events, writes one batch summary line to stdout in the form:
#
#   [HH:MM:SS] NEW <count> on <owner>/<name>: <type>/<action>#<ref>, ...
#
# Per-event detail goes to stderr. The Monitor watching the log only needs
# the stdout `NEW` lines to know when to wake the LLM-driven monitor agent.
#
# State per repo, atomic via *.tmp + mv:
#   <worktree>/.garden-monitor/<owner>-<name>/etag.txt
#   <worktree>/.garden-monitor/<owner>-<name>/last_event_id.txt
#
# Auth: uses `gh auth token` for the bearer. Token is read once at start;
# if it rotates mid-daemon the next 401 will be reported and the daemon
# will exit.

set -uo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <owner>/<name> <worktree-path> <cadence-seconds>" >&2
  exit 64
fi

REPO=$1
WT=$2
CADENCE=$3

OWNER=${REPO%/*}
NAME=${REPO#*/}
SLUG="${OWNER}-${NAME}"
STATE="$WT/.garden-monitor/$SLUG"
mkdir -p "$STATE"

TOKEN=$(gh auth token 2>/dev/null) || { echo "monitor-poll: gh auth token failed for $REPO" >&2; exit 1; }

trap 'echo "[$(date -u +%H:%M:%S)] daemon stopping repo=$REPO pid=$$"; exit 0' INT TERM

echo "[$(date -u +%H:%M:%S)] daemon starting repo=$REPO worktree=$WT cadence=${CADENCE}s pid=$$"

while true; do
  ETAG=$(cat "$STATE/etag.txt" 2>/dev/null || true)
  LAST_ID=$(cat "$STATE/last_event_id.txt" 2>/dev/null || echo 0)

  HEADERS=$(mktemp)
  BODY=$(mktemp)

  if [ -n "$ETAG" ]; then
    HTTP=$(curl -s -o "$BODY" -D "$HEADERS" -w '%{http_code}' \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "If-None-Match: $ETAG" \
      "https://api.github.com/repos/$REPO/events?per_page=30")
  else
    HTTP=$(curl -s -o "$BODY" -D "$HEADERS" -w '%{http_code}' \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$REPO/events?per_page=30")
  fi

  case "$HTTP" in
    304)
      ;;
    200)
      NEW_ETAG=$(grep -i '^etag:' "$HEADERS" | sed -E 's/^[Ee][Tt][Aa][Gg]: //; s/\r$//' | head -1)
      python3 - "$BODY" "$LAST_ID" "$STATE" "$REPO" <<'PY'
import json, sys, os, datetime
body, last_id, state, repo = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
try:
    events = json.load(open(body))
except Exception as e:
    sys.stderr.write(f"parse error: {e}\n")
    sys.exit(0)
events = [e for e in events if int(e['id']) > last_id]
events.sort(key=lambda e: int(e['id']))
if not events:
    sys.exit(0)
max_id = max(int(e['id']) for e in events)
parts = []
for e in events:
    t = e.get('type', '?')
    p = e.get('payload', {}) or {}
    ref = ''
    if isinstance(p, dict):
        if 'pull_request' in p and isinstance(p['pull_request'], dict):
            ref = f"#{p['pull_request'].get('number','')}"
        elif 'issue' in p and isinstance(p['issue'], dict):
            ref = f"#{p['issue'].get('number','')}"
        elif 'ref' in p and p['ref']:
            ref = f"@{p['ref']}"
        elif 'comment' in p and isinstance(p['comment'], dict):
            ref = f"@{p['comment'].get('html_url','')}"
    action = (p.get('action','') if isinstance(p, dict) else '') or ''
    parts.append(f"{t}/{action}{ref}".replace('/#','#').replace('/@','@'))
ts = datetime.datetime.utcnow().strftime('%H:%M:%S')
print(f"[{ts}] NEW {len(events)} on {repo}: " + ", ".join(parts), flush=True)
for e in events:
    actor = (e.get('actor') or {}).get('login', '?')
    sys.stderr.write(f"[{ts}]   id={e['id']} type={e['type']} actor={actor} created={e['created_at']}\n")
sys.stderr.flush()
tmp = state + '/last_event_id.txt.tmp'
with open(tmp, 'w') as f:
    f.write(str(max_id))
os.replace(tmp, state + '/last_event_id.txt')
PY
      if [ -n "$NEW_ETAG" ]; then
        printf '%s' "$NEW_ETAG" > "$STATE/etag.txt.tmp" && mv "$STATE/etag.txt.tmp" "$STATE/etag.txt"
      fi
      ;;
    401)
      echo "[$(date -u +%H:%M:%S)] HTTP 401 repo=$REPO (token rejected) — daemon stopping" >&2
      rm -f "$HEADERS" "$BODY"
      exit 1
      ;;
    403|429)
      RESET=$(grep -i '^x-ratelimit-reset:' "$HEADERS" | sed -E 's/^[^:]+:\s*//; s/\r$//' | head -1)
      REM=$(grep -i '^x-ratelimit-remaining:' "$HEADERS" | sed -E 's/^[^:]+:\s*//; s/\r$//' | head -1)
      echo "[$(date -u +%H:%M:%S)] HTTP $HTTP rate-limited repo=$REPO remaining=${REM:-?} reset=${RESET:-?}" >&2
      NOW=$(date -u +%s)
      if [ -n "${RESET:-}" ] && [[ "$RESET" =~ ^[0-9]+$ ]] && [ "$RESET" -gt "$NOW" ]; then
        sleep $((RESET - NOW + 1))
      else
        sleep 60
      fi
      ;;
    404)
      echo "[$(date -u +%H:%M:%S)] HTTP 404 repo=$REPO (missing or no access) — daemon stopping" >&2
      rm -f "$HEADERS" "$BODY"
      exit 1
      ;;
    *)
      echo "[$(date -u +%H:%M:%S)] HTTP $HTTP repo=$REPO" >&2
      head -c 500 "$BODY" >&2
      echo "" >&2
      ;;
  esac

  rm -f "$HEADERS" "$BODY"
  sleep "$CADENCE"
done
