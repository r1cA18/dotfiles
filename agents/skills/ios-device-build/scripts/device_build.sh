#!/bin/bash
# iOS実機ビルド・インストール・起動スクリプト
# Usage: device_build.sh [project_path] [scheme] [device_name] [bundle_id]
#
# パラメータ:
#   project_path - プロジェクトのパス（デフォルト: カレントディレクトリ）
#   scheme       - ビルドスキーム（デフォルト: 設定ファイル or xcodeproj名から自動検出）
#   device_name  - デバイス名（デフォルト: 設定ファイル or 接続中の最初のデバイス）
#   bundle_id    - バンドルID（デフォルト: Info.plistから自動取得）

set -e

# スキルディレクトリを特定
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-skills/ios-device-build"
CONFIG_FILE="$CONFIG_DIR/settings.conf"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 設定ファイルの読み込み（存在する場合）
DEFAULT_DEVICE_NAME=""
DEFAULT_SCHEME=""
NOTIFY_LANGUAGE="ja"
BUILD_LOG_LINES=30

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    log_info "設定ファイルを読み込みました"
fi

# パラメータ（引数 > 設定ファイル > デフォルト の優先順位）
PROJECT_PATH="${1:-.}"
SCHEME="${2:-$DEFAULT_SCHEME}"
DEVICE_NAME="${3:-$DEFAULT_DEVICE_NAME}"
BUNDLE_ID="${4:-}"

# プロジェクトパスに移動
cd "$PROJECT_PATH"
log_info "Working directory: $(pwd)"

# プロジェクトファイルを検出
if [ -z "$SCHEME" ]; then
    shopt -s nullglob
    WORKSPACES=(./*.xcworkspace)
    PROJECTS=(./*.xcodeproj)
    shopt -u nullglob
    if [ "${#WORKSPACES[@]}" -gt 0 ]; then
        XCWORKSPACE="${WORKSPACES[0]#./}"
        SCHEME=$(basename "$XCWORKSPACE" .xcworkspace)
        log_info "Detected workspace: $XCWORKSPACE"
    else
        if [ "${#PROJECTS[@]}" -eq 0 ]; then
            log_error "No .xcodeproj or .xcworkspace found in $(pwd)"
            exit 1
        fi
        XCODEPROJ="${PROJECTS[0]#./}"
        SCHEME=$(basename "$XCODEPROJ" .xcodeproj)
    fi
fi

# プロジェクトファイルを決定
if [ -f "${SCHEME}.xcworkspace/contents.xcworkspacedata" ]; then
    BUILD_TARGET=(-workspace "${SCHEME}.xcworkspace")
    log_info "Using workspace: ${SCHEME}.xcworkspace"
else
    BUILD_TARGET=(-project "${SCHEME}.xcodeproj")
    log_info "Using project: ${SCHEME}.xcodeproj"
fi
log_info "Scheme: $SCHEME"

# デバイス一覧を取得（availableデバイスのみ）
log_step "Searching for connected devices..."
DEVICE_LIST=$(xcrun devicectl list devices 2>/dev/null | grep -E "available" || true)

if [ -z "$DEVICE_LIST" ]; then
    log_error "No available devices found. Please connect your iOS device and make sure it's unlocked."
    exit 1
fi

# デバイスUDIDを取得（Hostnameからxcodebuild用のIDを抽出）
if [ -z "$DEVICE_NAME" ]; then
    DEVICE_LINE=$(echo "$DEVICE_LIST" | head -1)
    DETECTED_NAME=$(echo "$DEVICE_LINE" | awk '{print $1}')
    # Hostnameの形式: 00008120-000944D4113BA01E.coredevice.local
    DEVICE_UDID=$(echo "$DEVICE_LINE" | awk '{print $2}' | sed 's/\.coredevice\.local$//')
    log_info "Auto-detected device: $DETECTED_NAME"
else
    DEVICE_LINE=$(echo "$DEVICE_LIST" | grep -i "$DEVICE_NAME" | head -1)
    if [ -z "$DEVICE_LINE" ]; then
        log_error "Device '$DEVICE_NAME' not found among available devices."
        log_info "Available devices:"
        echo "$DEVICE_LIST"
        exit 1
    fi
    DEVICE_UDID=$(echo "$DEVICE_LINE" | awk '{print $2}' | sed 's/\.coredevice\.local$//')
fi

if [ -z "$DEVICE_UDID" ]; then
    log_error "Could not determine device UDID"
    exit 1
fi
log_info "Device UDID: $DEVICE_UDID"

# ビルド
log_step "Building for device..."
xcodebuild "${BUILD_TARGET[@]}" -scheme "$SCHEME" -destination "id=$DEVICE_UDID" build 2>&1 | tail -"$BUILD_LOG_LINES"

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    log_error "Build failed"
    exit 1
fi
log_info "Build succeeded"

# DerivedDataからappパスを検索（Index.noindexを除外）
log_step "Locating built app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "${SCHEME}.app" -path "*/Build/Products/Debug-iphoneos/*" -not -path "*/Index.noindex/*" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    log_error "Could not find built .app in DerivedData"
    exit 1
fi
log_info "App path: $APP_PATH"

# インストール
log_step "Installing to device..."
if ! xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"; then
    log_error "Installation failed"
    exit 1
fi
log_info "Installation succeeded"

# バンドルIDを取得
if [ -z "$BUNDLE_ID" ]; then
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null)
fi

if [ -z "$BUNDLE_ID" ]; then
    log_warn "Could not determine bundle ID. Skipping launch."
    exit 0
fi

# 起動
log_step "Launching app: $BUNDLE_ID"
if xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID"; then
    log_info "App launched successfully!"
    if [ "$NOTIFY_LANGUAGE" = "en" ]; then
        say "Build and launch completed"
    else
        say "ビルドと起動が完了しました"
    fi
else
    log_error "Launch failed"
    exit 1
fi
