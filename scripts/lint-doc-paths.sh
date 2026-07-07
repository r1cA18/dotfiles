#!/usr/bin/env bash
# Fail if a doc references a repo-relative path (in backticks) that does not exist.
# Scans Markdown for backtick-quoted paths starting with a known top-level dir.
set -euo pipefail

cd "$(dirname "$0")/.."

# Top-level dirs that denote a repo-relative path worth checking.
prefixes='nix/|docs/|agents/|claude/|codex/|nvim/|ghostty/|karabiner/|.github/|scripts/'

# Scan dotfiles-owned docs only. agents/skills/**/*.md is excluded: those skill
# manuals describe paths inside the target projects they operate on, not this repo.
files=$(git ls-files '*.md' ':(exclude)agents/skills/**' ':(exclude)**/node_modules/**' | sort -u)

missing=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  # Extract backtick-quoted tokens, keep those that look like repo paths.
  grep -oE '`[^`]+`' "$file" 2>/dev/null | tr -d '`' | while IFS= read -r token; do
    # Strip trailing punctuation/junk that commonly follows an inline path.
    path=${token%%[[:space:]]*}
    path=${path%.}
    path=${path%,}
    path=${path%:}
    path=${path%\)}
    case "$path" in
    *\** | *\<* | *\$* | *\{* | *xxx*) continue ;; # skip placeholders/globs
    esac
    if printf '%s\n' "$path" | grep -qE "^($prefixes)"; then
      if [ ! -e "$path" ]; then
        printf '%s: missing path `%s`\n' "$file" "$path"
      fi
    fi
  done
done <<<"$files" >/tmp/lint-doc-paths.$$ || true

if [ -s /tmp/lint-doc-paths.$$ ]; then
  echo "Dead documentation paths found:"
  cat /tmp/lint-doc-paths.$$
  missing=1
fi
rm -f /tmp/lint-doc-paths.$$
exit "$missing"
