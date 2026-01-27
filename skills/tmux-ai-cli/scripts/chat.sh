#!/bin/bash
# Send a prompt and capture the response
# Usage: ./chat.sh <target> "prompt" [wait_seconds] [session_name]

set -e

TARGET="$1"
PROMPT="$2"
WAIT="${3:-20}"
SESSION_NAME="${4:-ai-cli}"

if [ -z "$TARGET" ] || [ -z "$PROMPT" ]; then
    echo "Usage: $0 <gemini|codex> \"prompt\" [wait_seconds] [session_name]"
    echo ""
    echo "Examples:"
    echo "  $0 codex \"Hello, how are you?\""
    echo "  $0 gemini \"Explain async/await\" 30"
    echo "  $0 codex \"List files\" 15 my-session"
    exit 1
fi

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Session '$SESSION_NAME' not found"
    echo "Start one with: ./start_session.sh --auto-approve"
    exit 1
fi

# Map target to pane number
case "$TARGET" in
    gemini)
        PANE="$SESSION_NAME:main.0"
        ;;
    codex)
        PANE="$SESSION_NAME:main.1"
        ;;
    *)
        echo "Error: Target must be 'gemini' or 'codex'"
        exit 1
        ;;
esac

# Send prompt (text and Enter separately with small delay)
echo ">>> Sending to $TARGET: $PROMPT"
tmux send-keys -t "$PANE" "$PROMPT"
sleep 0.2
tmux send-keys -t "$PANE" C-m

# Wait for response
echo ">>> Waiting ${WAIT}s for response..."
sleep "$WAIT"

# Capture and display output
echo ""
echo "=== Response from $TARGET ==="
tmux capture-pane -t "$PANE" -p -S -50 | tail -30
echo "=============================="
