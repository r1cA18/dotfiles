#!/bin/bash
# Execute Codex review command
# Usage: ./codex_review.sh [options]

set -e

show_help() {
    echo "Usage: $0 [options] [custom_instruction]"
    echo ""
    echo "Options:"
    echo "  --uncommitted     Review uncommitted changes (staged + unstaged + untracked)"
    echo "  --base <branch>   Review changes against the specified branch"
    echo "  --commit <sha>    Review changes from a specific commit"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --uncommitted"
    echo "  $0 --base main"
    echo "  $0 --commit HEAD"
    echo "  $0 \"セキュリティ重視でレビューして\""
    echo "  $0 --uncommitted \"パフォーマンスに注目して\""
}

# Parse arguments
ARGS=()
CUSTOM_INSTRUCTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --uncommitted|--base|--commit)
            ARGS+=("$1")
            if [[ "$1" == "--base" || "$1" == "--commit" ]]; then
                shift
                ARGS+=("$1")
            fi
            shift
            ;;
        *)
            CUSTOM_INSTRUCTION="$1"
            shift
            ;;
    esac
done

# Default to --uncommitted if no args
if [ ${#ARGS[@]} -eq 0 ] && [ -z "$CUSTOM_INSTRUCTION" ]; then
    ARGS=("--uncommitted")
fi

echo ">>> Executing Codex Review"
if [ -n "$CUSTOM_INSTRUCTION" ]; then
    codex review "${ARGS[@]}" "$CUSTOM_INSTRUCTION"
else
    codex review "${ARGS[@]}"
fi
