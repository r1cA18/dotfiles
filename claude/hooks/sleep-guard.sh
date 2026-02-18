#!/bin/bash
set -euo pipefail

# sleep-guard.sh - Prevent macOS sleep during Claude Code sessions
# Usage: sleep-guard.sh start|stop|check|status
#
# Handles multiple parallel sessions with reference counting.
# Uses caffeinate (no sudo, auto-recovers on reboot).

GUARD_DIR="${TMPDIR:-/tmp}/claude-sleep-guard"
CAFE_PID_FILE="$GUARD_DIR/caffeinate.pid"
LOCKFILE="$GUARD_DIR/caffeinate.lock"

if ! mkdir -p "$GUARD_DIR" 2>/dev/null; then
    exit 1
fi
chmod 700 "$GUARD_DIR" 2>/dev/null || true

# Find a stable ancestor PID (skip intermediate shells to reach Claude Code)
get_session_pid() {
    local pid=$PPID
    while [ "$pid" -gt 1 ]; do
        local comm
        comm=$(ps -o comm= -p "$pid" 2>/dev/null || echo "")
        case "$comm" in
            sh|bash|zsh|dash|-bash|-zsh)
                local ppid
                ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
                if [ -z "$ppid" ] || [ "$ppid" -le 1 ] 2>/dev/null; then
                    echo "$PPID"
                    return
                fi
                pid="$ppid"
                ;;
            "")
                echo "$PPID"
                return
                ;;
            *)
                echo "$pid"
                return
                ;;
        esac
    done
    echo "$PPID"
}

# Remove stale session files (PIDs that no longer exist)
cleanup_stale() {
    for f in "$GUARD_DIR"/session_*; do
        [ -f "$f" ] || continue
        local spid="${f##*session_}"
        if [ -z "$spid" ] || ! kill -0 "$spid" 2>/dev/null; then
            rm -f "$f"
        fi
    done
}

count_sessions() {
    local count=0
    for f in "$GUARD_DIR"/session_*; do
        [ -f "$f" ] && count=$((count + 1))
    done
    echo "$count"
}

ensure_caffeinate() {
    (
        flock -x 200
        if [ -f "$CAFE_PID_FILE" ]; then
            local cafe_pid
            cafe_pid=$(cat "$CAFE_PID_FILE" 2>/dev/null)
            if [ -n "$cafe_pid" ] && kill -0 "$cafe_pid" 2>/dev/null; then
                return
            fi
        fi
        nohup caffeinate -d -i -s > /dev/null 2>&1 &
        disown $! 2>/dev/null || true
        echo $! > "$CAFE_PID_FILE"
    ) 200>"$LOCKFILE"
}

kill_caffeinate() {
    (
        flock -x 200
        if [ -f "$CAFE_PID_FILE" ]; then
            local cafe_pid
            cafe_pid=$(cat "$CAFE_PID_FILE" 2>/dev/null)
            if [ -n "$cafe_pid" ]; then
                kill "$cafe_pid" 2>/dev/null || true
            fi
            rm -f "$CAFE_PID_FILE"
        fi
    ) 200>"$LOCKFILE"
}

SESSION_PID=$(get_session_pid)

case "${1:-}" in
    start)
        cleanup_stale
        touch "$GUARD_DIR/session_${SESSION_PID}"
        ensure_caffeinate
        ;;
    stop)
        rm -f "$GUARD_DIR/session_${SESSION_PID}"
        cleanup_stale
        if [ "$(count_sessions)" -eq 0 ]; then
            kill_caffeinate
        fi
        ;;
    check)
        # Cleanup only (no deregister). Safe to run on every Stop hook.
        cleanup_stale
        if [ "$(count_sessions)" -eq 0 ]; then
            kill_caffeinate
        fi
        ;;
    status)
        cleanup_stale
        echo "Sessions: $(count_sessions)"
        for f in "$GUARD_DIR"/session_*; do
            [ -f "$f" ] || continue
            echo "  PID: ${f##*session_}"
        done
        if [ -f "$CAFE_PID_FILE" ]; then
            local cafe_pid
            cafe_pid=$(cat "$CAFE_PID_FILE" 2>/dev/null)
            if [ -n "$cafe_pid" ] && kill -0 "$cafe_pid" 2>/dev/null; then
                echo "Caffeinate: running (PID $cafe_pid)"
            else
                echo "Caffeinate: not running"
            fi
        else
            echo "Caffeinate: not running"
        fi
        ;;
esac
