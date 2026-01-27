#!/bin/bash
# Start a tmux session with Gemini and Codex in split panes
# Usage: ./start_session.sh [--auto-approve|-y] [session_name]

set -e

SESSION_NAME="ai-cli"
AUTO_APPROVE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --auto-approve|-y)
            AUTO_APPROVE=true
            ;;
        -*)
            echo "Unknown option: $arg"
            exit 1
            ;;
        *)
            SESSION_NAME="$arg"
            ;;
    esac
done

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Session '$SESSION_NAME' already exists"
    echo "Use './scripts/session.sh kill $SESSION_NAME' to remove it"
    exit 1
fi

# Build CLI commands based on auto-approve flag
if [ "$AUTO_APPROVE" = true ]; then
    GEMINI_CMD="gemini -y"
    CODEX_CMD="codex --dangerously-bypass-approvals-and-sandbox"
    echo "Starting in auto-approve mode (YOLO)"
else
    GEMINI_CMD="gemini"
    CODEX_CMD="codex"
fi

# Create session with split panes (left: Gemini, right: Codex)
tmux new-session -d -s "$SESSION_NAME" -n main

# Split horizontally (left/right)
tmux split-window -h -t "$SESSION_NAME:main"

# Start Gemini in left pane (.0)
tmux send-keys -t "$SESSION_NAME:main.0" "$GEMINI_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:main.0" C-m

# Start Codex in right pane (.1)
tmux send-keys -t "$SESSION_NAME:main.1" "$CODEX_CMD"
sleep 0.2
tmux send-keys -t "$SESSION_NAME:main.1" C-m

echo "Session '$SESSION_NAME' created (split view)"
echo "  - Left pane (.0):  $GEMINI_CMD"
echo "  - Right pane (.1): $CODEX_CMD"
echo ""
echo "Commands:"
echo "  tmux attach -t $SESSION_NAME        # Attach"
echo "  ./scripts/chat.sh gemini \"Hello\"   # Chat with Gemini"
echo "  ./scripts/chat.sh codex \"Hello\"    # Chat with Codex"
echo "  ./scripts/session.sh kill           # Kill session"
