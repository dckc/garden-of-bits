#!/bin/bash
# run-steward-cycle.sh — one steward cycle for the opencode harness.
#
# Usage:
#   ./run-steward-cycle.sh [--dry-run] [--quiet] [--triggered-by=SOURCE]
#
# This is the cron entry point. It runs the deterministic parts of one
# steward cycle inline (journal sync, monitor liveness, inbox drain) and
# then invokes `opencode run` for the LLM-driven parts (dispatch decisions,
# subagent orchestration, journaling).
#
# --triggered-by=SOURCE  Source that triggered this cycle: cron (default)
#                        or watcher. The watcher daemon passes this so the
#                        cycle can log the trigger source.
#
# The opencode session starts with a prompt that overrides the liaison
# default in CLAUDE.md so the agent acts as the steward.
#
# Environment:
#   OPENCODE_MODEL   Model to use (default: opencode/deepseek-v4-flash-free)
#   STEWARD_DRY      If set, skip the opencode invocation
#   STEWARD_QUIET    If set, suppress non-error output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

HOST="$(hostname -s)"
DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE_YMD="$(date -u +%Y/%m/%d)"
CYCLE_FILE="/tmp/garden-steward-cycle-${HOST}.txt"

TRIGGERED_BY="cron"
DRY_RUN="${STEWARD_DRY:-0}"
QUIET="${STEWARD_QUIET:-0}"

# Parse arguments. Positional: --dry-run, --quiet, --triggered-by=SOURCE
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --quiet) QUIET=1 ;;
        --triggered-by=*) TRIGGERED_BY="${arg#*=}" ;;
    esac
done

log() { [ "$QUIET" -eq 0 ] && echo "$*"; }
err() { echo "$*" >&2; }

log "=== Steward cycle starting at $DATE_UTC on $HOST (trigger: $TRIGGERED_BY) ==="

# --- Step 1: Journal sync ---
log "--- Syncing journal ---"
JRN="$SCRIPT_DIR/journal"
if git -C "$JRN" remote get-url origin &>/dev/null; then
    git -C "$JRN" fetch --quiet origin journal 2>/dev/null || true
    AHEAD=$(git -C "$JRN" rev-list --count origin/journal..HEAD 2>/dev/null || echo 0)
    BEHIND=$(git -C "$JRN" rev-list --count HEAD..origin/journal 2>/dev/null || echo 0)
    if [ "$AHEAD" = "0" ] && [ "$BEHIND" != "0" ]; then
        git -C "$JRN" reset --hard origin/journal
        log "  journal fast-forwarded"
    elif [ "$AHEAD" != "0" ] && [ "$BEHIND" != "0" ]; then
        git -C "$JRN" rebase origin/journal 2>/dev/null || {
            git -C "$JRN" rebase --abort 2>/dev/null || true
            err "  journal rebase conflict; proceeding with local state"
        }
    fi
else
    log "  no remote configured; local-only"
fi

CUR_HEAD="$(git -C "$JRN" rev-parse HEAD)"
log "  journal HEAD: ${CUR_HEAD:0:12}"

# --- Step 2: Standing monitor liveness check ---
log "--- Checking standing monitors ---"
MONITOR_STATE=""

check_daemon() {
    local pid_file="$1"
    local name="$2"
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log "  $name: alive (pid $pid)"
            echo "alive"
        else
            log "  $name: DEAD (pid $pid stale)"
            echo "dead"
        fi
    else
        log "  $name: not started"
        echo "not-started"
    fi
}

MON_GARDEN=$(check_daemon "/tmp/garden-monitor-dckc-garden-of-bits.pid" "dckc/garden-of-bits")
MON_JESC24=$(check_daemon "/tmp/garden-monitor-dctinybrain-jesc24.pid" "dctinybrain/jesc24")
MONITOR_STATE="garden=$MON_GARDEN jesc24=$MON_JESC24"

# Check daemon logs for NEW/ADD/REMOVE lines
check_log_lines() {
    local log_file="$1"
    if [ -f "$log_file" ]; then
        wc -l < "$log_file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

LOG_GARDEN_LINES=$(check_log_lines "/tmp/garden-monitor-dckc-garden-of-bits.log")
LOG_JESC24_LINES=$(check_log_lines "/tmp/garden-monitor-dctinybrain-jesc24.log")

# Check steward watcher daemon liveness
WATCHER_STATE=""
WATCHER_PID_FILE="/tmp/garden-steward-watcher-${HOST}.pid"
if [ -f "$WATCHER_PID_FILE" ]; then
    WPID=$(cat "$WATCHER_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$WPID" ] && kill -0 "$WPID" 2>/dev/null; then
        WATCHER_STATE="alive (pid $WPID)"
        log "  steward-watcher: alive (pid $WPID)"
    else
        WATCHER_STATE="dead"
        log "  steward-watcher: DEAD (pid $WPID stale)"
    fi
else
    WATCHER_STATE="not-started"
    log "  steward-watcher: not started"
fi

# --- Unconditional monitor respawn ---
if [ "$MON_GARDEN" != "alive" ]; then
    log "  respawning dckc/garden-of-bits monitor (was $MON_GARDEN)"
    nohup bash "$SCRIPT_DIR/skills/github-activity-poll/monitor-poll.sh" dckc/garden-of-bits \
      "$SCRIPT_DIR/worktrees/dckc-garden-of-bits/watch-garden-of-bits--monitor--20260515-125353" 60s \
      > /tmp/garden-monitor-dckc-garden-of-bits.log \
      2> /tmp/garden-monitor-dckc-garden-of-bits.err &
    echo $! > /tmp/garden-monitor-dckc-garden-of-bits.pid
    MON_GARDEN="alive"
fi

if [ "$MON_JESC24" != "alive" ]; then
    log "  respawning dctinybrain/jesc24 monitor (was $MON_JESC24)"
    nohup bash "$SCRIPT_DIR/skills/github-activity-poll/monitor-poll.sh" dctinybrain/jesc24 \
      "$SCRIPT_DIR/worktrees/dctinybrain-jesc24/watch-jesc24--monitor--20260516-232644" 60s \
      > /tmp/garden-monitor-dctinybrain-jesc24.log \
      2> /tmp/garden-monitor-dctinybrain-jesc24.err &
    echo $! > /tmp/garden-monitor-dctinybrain-jesc24.pid
    MON_JESC24="alive"
fi

MONITOR_STATE="garden=$MON_GARDEN jesc24=$MON_JESC24"

# --- Step 3: Inbox drain ---
log "--- Draining steward inbox ---"
INBOX_OUTPUT=""
if [ -f "$SCRIPT_DIR/skills/inbox-drain/inbox-drain.sh" ]; then
    INBOX_OUTPUT=$(bash "$SCRIPT_DIR/skills/inbox-drain/inbox-drain.sh" steward --no-fetch 2>&1 || true)
fi
INBOX_COUNT=$(echo "$INBOX_OUTPUT" | grep -c . || true)

# --- Step 4: Check for lingering dispatch worktrees ---
log "--- Checking dispatch worktrees ---"
DISPATCH_COUNT=0
DISPATCH_LIST=""
if [ -d "$SCRIPT_DIR/dispatches" ]; then
    DISPATCH_COUNT=$(find "$SCRIPT_DIR/dispatches" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    DISPATCH_LIST=$(find "$SCRIPT_DIR/dispatches" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | tr '\n' ' ')
fi

# --- Step 5: Write pre-flight state file ---
cat > "$CYCLE_FILE" <<PREFLIGHT
steward_cycle_ts: $DATE_UTC
host: $HOST
triggered_by: $TRIGGERED_BY
journal_head: ${CUR_HEAD:0:12}
monitors: $MONITOR_STATE
watcher: $WATCHER_STATE
inbox_count: $INBOX_COUNT
dispatch_worktrees: $DISPATCH_COUNT
inbox_lines: |
$(echo "$INBOX_OUTPUT" | sed 's/^/  /')
PREFLIGHT

# --- Step 6: Invoke opencode for LLM-driven cycle ---
if [ "$DRY_RUN" -eq 1 ]; then
    log "=== DRY RUN — skipping opencode invocation ==="
    log "Pre-flight state written to $CYCLE_FILE"
    exit 0
fi

# Check that opencode is available
if ! command -v opencode &>/dev/null; then
    NVM_OPENCODE="$HOME/.nvm/versions/node/v22.22.2/bin/opencode"
    if [ -x "$NVM_OPENCODE" ]; then
        export PATH="$(dirname "$NVM_OPENCODE"):$PATH"
    else
        err "opencode not found in PATH"
        exit 1
    fi
fi

MODEL="${OPENCODE_MODEL:-opencode/deepseek-v4-flash-free}"

log "=== Invoking opencode for steward cycle ==="
log "  model: $MODEL"
log "  inbox: $INBOX_COUNT new messages"
log "  dispatches: $DISPATCH_COUNT pending"

# Build the steward dispatch prompt. This overrides the liaison framing
# in CLAUDE.md by explicitly naming the role and providing the same
# per-cycle procedure the original steward uses.
STEWARD_PROMPT="You are operating as role=steward in the garden at $SCRIPT_DIR.

This is an autonomous steward cycle started by $TRIGGERED_BY on $HOST at $DATE_UTC.

IMPORTANT: Despite what CLAUDE.md says, you are the STEWARD, not the liaison.
The liaison is not present. There is no user in the loop.

PRE-FLIGHT STATE:
- Host: $HOST
- Trigger: $TRIGGERED_BY
- Journal HEAD: ${CUR_HEAD:0:12}
- Monitors: $MONITOR_STATE
- Watcher: $WATCHER_STATE
- Inbox messages: $INBOX_COUNT
- Pending dispatch worktrees: $DISPATCH_COUNT

INBOX LINES:
$(echo "$INBOX_OUTPUT" | sed 's/^/> /')

Run one steward cycle using the per-cycle procedure in garden/roles/steward/AGENT.md.
Read garden/roles/COMMON.md first, then garden/roles/steward/AGENT.md.

OPencode ADAPTATION NOTES (this is opencode, not Claude Code):
1. Use the \`Task\` tool to dispatch subagents, NOT the \`Agent\` tool (it does not exist).
2. There is no ScheduleWakeup tool. This cycle runs once and exits; cron handles the next cycle.
3. The steward-watcher daemon (run-steward-watcher.sh) replaces the old parent-context Monitor tasks. Check daemon logs inline and verify the watcher is alive.
4. Use \`bash\` to run shell commands (git, gh, journal operations).
5. Use \`bash\` to call dispatch-prepare.sh / dispatch-teardown.sh for worktree management.
6. The \`garden\` worktree is at $SCRIPT_DIR, the \`journal\` worktree is at $SCRIPT_DIR/journal.
7. For github operations, \`gh\` is authenticated as dctinybrain.

Write a cycle-summary 'result' journal entry when done. Then report back a
concise summary of what happened this cycle."

exec opencode run \
    --dir "$SCRIPT_DIR" \
    --model "$MODEL" \
    --dangerously-skip-permissions \
    "$STEWARD_PROMPT"
