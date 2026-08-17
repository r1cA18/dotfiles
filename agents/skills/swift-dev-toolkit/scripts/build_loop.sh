#!/bin/bash
# Swift Build Loop - エラーがなくなるまでビルドを繰り返す
# Usage: build_loop.sh <project_path> <scheme> <platform>
# platform: ios, macos, or both

set -e

PROJECT_PATH="$(cd "${1:-.}" && pwd)"
SCHEME="${2:-}"
PLATFORM="${3:-ios}"

cd "$PROJECT_PATH"

# スキーム自動検出
if [ -z "$SCHEME" ]; then
    shopt -s nullglob
    PROJECTS=(./*.xcodeproj)
    shopt -u nullglob
    if [ "${#PROJECTS[@]}" -gt 0 ]; then
        XCODEPROJ="${PROJECTS[0]#./}"
        SCHEME=$(basename "$XCODEPROJ" .xcodeproj)
    else
        echo "Error: No .xcodeproj found and no scheme specified"
        exit 1
    fi
fi

echo "=== Swift Build Loop ==="
echo "Project: $PROJECT_PATH"
echo "Scheme: $SCHEME"
echo "Platform: $PLATFORM"
echo ""

# プラットフォームに応じた destination 設定
case "$PLATFORM" in
    ios)
        DESTINATION="generic/platform=iOS Simulator"
        ;;
    macos)
        DESTINATION="platform=macOS"
        ;;
    both)
        echo "Building for iOS first, then macOS..."
        "$0" "$PROJECT_PATH" "$SCHEME" ios
        "$0" "$PROJECT_PATH" "$SCHEME" macos
        exit 0
        ;;
    *)
        echo "Unknown platform: $PLATFORM"
        exit 1
        ;;
esac

# ビルド実行
echo "Building for $PLATFORM..."
BUILD_LOG="/tmp/build_${SCHEME}_${PLATFORM}.log"

xcodebuild \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -configuration Debug \
    build 2>&1 | tee "$BUILD_LOG"

# エラーチェック
ERRORS=$(grep -c "error:" "$BUILD_LOG" 2>/dev/null || echo "0")

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "=== Build Errors ($ERRORS) ==="
    grep -A2 "error:" "$BUILD_LOG" | head -50
    echo ""
    echo "Build log: $BUILD_LOG"
    exit 1
else
    echo ""
    echo "=== BUILD SUCCEEDED ==="
    exit 0
fi
