#!/bin/bash
# run-steward-watcher.sh — continuous event watcher for steward cycles.
#
# Replaces the original parent-context Monitor tasks from the Claude Code
# garden. A bash daemon that runs continuously (via nohup), watches daemon
# monitor logs for signal lines (NEW|ERROR|daemon stopping), drains the
# steward's inbox periodically, and triggers a steward cycle when any
# signal appears.
#
# Usage:
#   ./run-steward-watcher.sh              # run in foreground
#   ./run-steward-watcher.sh --daemon     # fork to background (via nohup)
#   ./run-steward-watcher.sh --stop       # stop a running watcher
#   ./run-steward-watcher.sh --status     # check if running
#   ./run-steward-watcher.sh --restart    # stop then start
#
# Environment:
#   STEWARD_WATCHER_DEBUG       Set to 1 for verbose logging (default: 0)
#   STEWARD_WATCHER_COOLDOWN    Min seconds between steward cycle
#                               invocations (default: 60)
#   STEWARD_WATCHER_INBOX_INT   Inbox drain interval in seconds
#                               (default: 90)
#   STEWARD_WATCHER_POLL_INT    Log file poll interval in seconds
#                               (default: 15)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST="$(hostname -s)"
PID_FILE="/tmp/garden-steward-watcher-${HOST}.pid"
LOG_FILE="/tmp/garden-steward-watcher-${HOST}.log"
STATE_DIR="/tmp/garden-steward-watcher-${HOST}.d"

COOLDOWN_SECS="${STEWARD_WATCHER_COOLDOWN:-60}"
INBOX_INTERVAL="${STEWARD_WATCHER_INBOX_INT:-90}"
POLL_INTERVAL="${STEWARD_WATCHER_POLL_INT:-15}"
DEBUG="${STEWARD_WATCHER_DEBUG:-0}"

# ---------- helpers ----------

log() {
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "[$ts] $*" >> "$LOG_FILE"
}

debug() {
    [ "$DEBUG" -eq 1 ] && log "DEBUG: $*" || true
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

# ---------- lifecycle ----------

do_stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Watcher not running (no pid file)."
        exit 0
    fi
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -z "$pid" ]; then
        rm -f "$PID_FILE"
        echo "Watcher not running (empty pid file, cleaned up)."
        exit 0
    fi
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        for i in 1 2 3 4 5; do
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        echo "Watcher (pid $pid) stopped."
    else
        echo "Watcher pid $pid not alive; cleaning up stale pid file."
    fi
    rm -f "$PID_FILE"
}

do_status() {
    if [ ! -f "$PID_FILE" ]; then
        echo "not running"
        exit 1
    fi
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -z "$pid" ]; then
        echo "not running (empty pid file)"
        exit 1
    fi
    if kill -0 "$pid" 2>/dev/null; then
        local uptime_secs=0
        if [ -f "$STATE_DIR/started_at" ]; then
            local started
            started="$(cat "$STATE_DIR/started_at")"
            local now
            now="$(date -u +%s)"
            uptime_secs=$(( now - started ))
        fi
        echo "running (pid $pid, uptime ${uptime_secs}s)"
        exit 0
    else
        echo "not running (stale pid $pid)"
        exit 1
    fi
}

# ---------- signal detection ----------

# Check monitor logs for new content with signal lines (NEW|ERROR|daemon stopping).
# Returns 0 (true) if signal lines found in newly-grown content.
check_monitor_logs() {
    local state_file="$STATE_DIR/monitor_log_sizes"
    touch "$state_file"
    local found_new=0

    for log_path in /tmp/garden-monitor-*.log; do
        [ -f "$log_path" ] || continue
        local log_name
        log_name="$(basename "$log_path")"
        local current_size
        current_size="$(stat -c%s "$log_path" 2>/dev/null || echo 0)"
        local last_size
        last_size="$(grep "^${log_name}:" "$state_file" 2>/dev/null | cut -d: -f2 || echo 0)"

        if [ "$current_size" -gt "$last_size" ]; then
            local new_bytes=$(( current_size - last_size ))
            local tail_content
            tail_content="$(tail -c "$new_bytes" "$log_path" 2>/dev/null || true)"
            if echo "$tail_content" | grep -qE 'NEW|daemon stopping|ERROR'; then
                log "Signal detected in $log_name (${new_bytes} new bytes, contains NEW/ERROR)"
                found_new=1
            fi
            if grep -q "^${log_name}:" "$state_file" 2>/dev/null; then
                sed -i "s/^${log_name}:.*/${log_name}:${current_size}/" "$state_file"
            else
                echo "${log_name}:${current_size}" >> "$state_file"
            fi
        fi
    done

    [ "$found_new" -eq 1 ]
}

# Check the steward's inbox for new messages.
# Returns 0 (true) if new messages found.
check_inbox() {
    local output
    output="$(bash "$SCRIPT_DIR/skills/inbox-drain/inbox-drain.sh" steward --no-fetch 2>/dev/null || true)"
    if [ -n "$output" ]; then
        local count
        count="$(echo "$output" | grep -c . || true)"
        log "Inbox drain found $count new message(s)"
        return 0
    fi
    return 1
}

# ---------- cycle trigger ----------

LAST_TRIGGER_FILE="$STATE_DIR/last_trigger_ts"

can_trigger() {
    if [ ! -f "$LAST_TRIGGER_FILE" ]; then
        echo 0 > "$LAST_TRIGGER_FILE"
        return 0
    fi
    local last
    last="$(cat "$LAST_TRIGGER_FILE")"
    local now
    now="$(date -u +%s)"
    local elapsed=$(( now - last ))
    [ "$elapsed" -ge "$COOLDOWN_SECS" ]
}

trigger_steward_cycle() {
    local reason="$1"
    local now
    now="$(date -u +%s)"
    echo "$now" > "$LAST_TRIGGER_FILE"
    log "Triggering steward cycle (reason: $reason)"
    bash "$SCRIPT_DIR/run-steward-cycle.sh" --triggered-by=watcher --quiet \
        >> "$LOG_FILE" 2>&1 &
    log "  steward cycle launched (pid $!)"
}

# ---------- main loop ----------

run_daemon() {
    ensure_state_dir
    echo "$(date -u +%s)" > "$STATE_DIR/started_at"
    echo "$$" > "$PID_FILE"

    log "Watcher daemon starting (pid $$, host $HOST)"
    log "  inbox interval: ${INBOX_INTERVAL}s"
    log "  poll interval: ${POLL_INTERVAL}s"
    log "  cooldown: ${COOLDOWN_SECS}s"
    log "  cycle script: $SCRIPT_DIR/run-steward-cycle.sh"

    # Initialize monitor log sizes from current files
    for log_path in /tmp/garden-monitor-*.log; do
        [ -f "$log_path" ] || continue
        local log_name
        log_name="$(basename "$log_path")"
        local size
        size="$(stat -c%s "$log_path" 2>/dev/null || echo 0)"
        echo "${log_name}:${size}" >> "$STATE_DIR/monitor_log_sizes"
    done

    local inbox_counter=0
    local inbox_limit=$(( INBOX_INTERVAL / POLL_INTERVAL ))
    [ "$inbox_limit" -lt 1 ] && inbox_limit=1

    while true; do
        # Check monitor logs for signal lines
        if check_monitor_logs; then
            if can_trigger; then
                trigger_steward_cycle "monitor-log-signal"
            else
                debug "monitor log signal within cooldown; deferring"
            fi
        fi

        # Periodically drain the inbox
        inbox_counter=$(( inbox_counter + 1 ))
        if [ "$inbox_counter" -ge "$inbox_limit" ]; then
            inbox_counter=0
            git -C "$SCRIPT_DIR/journal" fetch --quiet origin journal 2>/dev/null || true
            git -C "$SCRIPT_DIR/journal" merge --ff-only --quiet origin/journal 2>/dev/null || true
            if check_inbox; then
                if can_trigger; then
                    trigger_steward_cycle "inbox-message"
                else
                    debug "inbox message within cooldown; deferring"
                fi
            fi
        fi

        sleep "$POLL_INTERVAL"
    done
}

# ---------- entry point ----------

case "${1:-}" in
    --daemon)
        nohup "$0" --foreground >> "$LOG_FILE" 2>&1 &
        echo "$!" > "$PID_FILE"
        echo "Watcher daemon started (pid $(cat "$PID_FILE"))"
        ;;
    --foreground)
        run_daemon
        ;;
    --stop)
        do_stop
        ;;
    --status)
        do_status
        ;;
    --restart)
        do_stop
        sleep 1
        exec "$0" --daemon
        ;;
    "")
        run_daemon
        ;;
    *)
        echo "Usage: $(basename "$0") [--daemon|--stop|--status|--restart]" >&2
        exit 1
        ;;
esac
