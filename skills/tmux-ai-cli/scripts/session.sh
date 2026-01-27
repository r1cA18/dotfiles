#!/bin/bash
# Manage tmux AI CLI sessions
# Usage: ./session.sh <command> [session_name]

set -e

CMD="${1:-status}"
SESSION_NAME="${2:-ai-cli}"

case "$CMD" in
    status|s)
        if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
            echo "Session '$SESSION_NAME' is running"
            echo ""
            tmux list-windows -t "$SESSION_NAME"
        else
            echo "Session '$SESSION_NAME' not found"
        fi
        ;;
    kill|k)
        if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
            tmux kill-session -t "$SESSION_NAME"
            echo "Session '$SESSION_NAME' killed"
        else
            echo "Session '$SESSION_NAME' not found"
        fi
        ;;
    attach|a)
        if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
            tmux attach -t "$SESSION_NAME"
        else
            echo "Session '$SESSION_NAME' not found"
            exit 1
        fi
        ;;
    list|l)
        echo "Active tmux sessions:"
        tmux list-sessions 2>/dev/null || echo "No sessions"
        ;;
    *)
        echo "Usage: $0 <command> [session_name]"
        echo ""
        echo "Commands:"
        echo "  status, s  - Check if session exists"
        echo "  kill, k    - Kill session"
        echo "  attach, a  - Attach to session"
        echo "  list, l    - List all sessions"
        exit 1
        ;;
esac
