#!/usr/bin/env bash
# Run repository tests without changing the active user or system configuration.
set -euo pipefail

cd "$(dirname "$0")/.."
suite=${1:-unit}
if [ "$#" -gt 1 ]; then
  printf 'Usage: bash scripts/test.sh [unit|integration|all]\n' >&2
  exit 2
fi

require_commands() {
  local missing=() command
  for command in "$@"; do
    command -v "$command" >/dev/null 2>&1 || missing+=("$command")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing test dependencies: %s\n' "${missing[*]}" >&2
    printf 'Use the Nix shell command in docs/guides/testing.md to provide them.\n' >&2
    return 127
  fi
}

unit() {
  bash scripts/lint-doc-paths.sh
  DOTFILES_TEST_NIX=0 WORKSPACE_BIN= INDEXION_BIN= \
    bun test tests agents/hooks claude/hooks agents/skills
}

integration() {
  require_commands nix bun git ghq rg jq python3 zsh fzf find awk grep sed
  case "$(uname -s):$(uname -m)" in
  Darwin:arm64 | Linux:x86_64) ;;
  *)
    printf 'Nix integration tests support Apple Silicon macOS and x86_64 Linux only.\n' >&2
    return 2
    ;;
  esac
  local workspace_package indexion_package
  workspace_package=$(nix build --no-write-lock-file "path:$PWD#workspace" --no-link --print-out-paths)
  indexion_package=$(nix build --no-write-lock-file "path:$PWD#indexion" --no-link --print-out-paths)
  DOTFILES_TEST_NIX=1 WORKSPACE_BIN="$workspace_package/bin/workspace" \
    INDEXION_BIN="$indexion_package/bin/indexion" \
    bun test tests
}

case "$suite" in
unit)
  require_commands bash bun git ghq rg jq python3 zsh fzf find awk grep sed
  unit
  ;;
integration) integration ;;
all)
  require_commands bash bun git ghq rg jq python3 zsh fzf find awk grep sed
  unit
  integration
  ;;
*)
  printf 'Usage: bash scripts/test.sh [unit|integration|all]\n' >&2
  exit 2
  ;;
esac
