#!/bin/bash
# Capture output from a tmux pane
# Usage: ./capture_output.sh [target] [lines] [session_name]

TARGET="${1:-gemini}"
LINES="${2:-100}"
SESSION_NAME="${3:-ai-cli}"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Session '$SESSION_NAME' not found" >&2
    exit 1
fi

# Map target to pane
case "$TARGET" in
    gemini)
        PANE="$SESSION_NAME:main.0"
        ;;
    codex)
        PANE="$SESSION_NAME:main.1"
        ;;
    both)
        echo "=== Gemini ==="
        tmux capture-pane -t "$SESSION_NAME:main.0" -p -S "-$LINES"
        echo ""
        echo "=== Codex ==="
        tmux capture-pane -t "$SESSION_NAME:main.1" -p -S "-$LINES"
        exit 0
        ;;
    *)
        echo "Error: Target must be 'gemini', 'codex', or 'both'" >&2
        exit 1
        ;;
esac

tmux capture-pane -t "$PANE" -p -S "-$LINES"
