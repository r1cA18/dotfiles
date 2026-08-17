#!/bin/bash
# FrameScript プロジェクト初期化スクリプト

PROJECT_NAME=${1:-my-video-project}

echo "Creating FrameScript project: $PROJECT_NAME"
bunx @frame-script/create-frame-script "$PROJECT_NAME"

if [ -d "$PROJECT_NAME" ]; then
    cd "$PROJECT_NAME" || exit 1
    bun install
    echo ""
    echo "Project created successfully!"
    echo ""
    echo "Next steps:"
    echo "  cd $PROJECT_NAME"
    echo "  bun run start    # プレビュー起動"
    echo "  bun run render   # レンダリング"
else
    echo "Error: Failed to create project"
    exit 1
fi
