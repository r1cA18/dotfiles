#!/bin/bash
# Send a prompt to both Gemini and Codex, optionally wait and capture
# Usage: ./send_to_both.sh "prompt" [--wait seconds] [session_name]

set -e

PROMPT=""
WAIT=0
SESSION_NAME="ai-cli"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --wait|-w)
            WAIT="$2"
            shift 2
            ;;
        *)
            if [ -z "$PROMPT" ]; then
                PROMPT="$1"
            else
                SESSION_NAME="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$PROMPT" ]; then
    echo "Usage: $0 \"prompt\" [--wait seconds] [session_name]"
    echo ""
    echo "Examples:"
    echo "  $0 \"Explain recursion\""
    echo "  $0 \"Write hello world\" --wait 20"
    echo "  $0 \"List files\" --wait 15 my-session"
    exit 1
fi

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Session '$SESSION_NAME' not found"
    exit 1
fi

GEMINI_PANE="$SESSION_NAME:main.0"
CODEX_PANE="$SESSION_NAME:main.1"

echo ">>> Sending to both: $PROMPT"
tmux send-keys -t "$GEMINI_PANE" "$PROMPT"
sleep 0.2
tmux send-keys -t "$GEMINI_PANE" C-m
tmux send-keys -t "$CODEX_PANE" "$PROMPT"
sleep 0.2
tmux send-keys -t "$CODEX_PANE" C-m

if [ "$WAIT" -gt 0 ]; then
    echo ">>> Waiting ${WAIT}s..."
    sleep "$WAIT"

    echo ""
    echo "=== Gemini ==="
    tmux capture-pane -t "$GEMINI_PANE" -p -S -50 | tail -25
    echo ""
    echo "=== Codex ==="
    tmux capture-pane -t "$CODEX_PANE" -p -S -50 | tail -25
    echo "=============="
else
    echo "Done. Use capture_output.sh to see responses."
fi
