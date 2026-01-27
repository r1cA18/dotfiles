#!/bin/bash
# Execute Gemini CLI with a prompt (non-interactive)
# Usage: ./gemini_exec.sh "your prompt"

set -e

PROMPT="$1"

if [ -z "$PROMPT" ]; then
    echo "Usage: $0 \"your prompt\""
    echo ""
    echo "Examples:"
    echo "  $0 \"TypeScript 5.5の新機能を調べて\""
    echo "  $0 \"React 19の変更点を教えて\""
    exit 1
fi

echo ">>> Executing Gemini: $PROMPT"
gemini -y "$PROMPT"
