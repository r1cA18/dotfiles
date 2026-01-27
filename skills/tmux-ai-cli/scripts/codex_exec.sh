#!/bin/bash
# Execute Codex CLI with a prompt (non-interactive)
# Usage: ./codex_exec.sh "your prompt" [directory]

set -e

PROMPT="$1"
DIR="${2:-$(pwd)}"

if [ -z "$PROMPT" ]; then
    echo "Usage: $0 \"your prompt\" [directory]"
    echo ""
    echo "Examples:"
    echo "  $0 \"このプロジェクトの構造を説明して\""
    echo "  $0 \"バグの原因を調査して\" /path/to/project"
    exit 1
fi

echo ">>> Executing Codex in $DIR"
echo ">>> Prompt: $PROMPT"
codex exec --full-auto --sandbox read-only --cd "$DIR" "$PROMPT"
