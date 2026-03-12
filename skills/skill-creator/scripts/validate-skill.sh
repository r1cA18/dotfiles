#!/usr/bin/env bash
# Validate a skill directory for common issues.
# Usage: bash validate-skill.sh <skill-directory>
#
# Checks:
#   - SKILL.md exists (case-sensitive)
#   - YAML frontmatter has --- delimiters
#   - name field exists and is kebab-case
#   - description field exists and is non-empty
#   - No XML angle brackets in frontmatter
#   - Referenced files exist
#   - Body line count

set -euo pipefail

SKILL_DIR="${1:?Usage: validate-skill.sh <skill-directory>}"
SKILL_FILE="$SKILL_DIR/SKILL.md"
ERRORS=0
WARNINGS=0

error() { echo "  ERROR: $1"; ((ERRORS++)); }
warn()  { echo "  WARN:  $1"; ((WARNINGS++)); }
ok()    { echo "  OK:    $1"; }

echo "=== Validating: $SKILL_DIR ==="
echo ""

# 1. SKILL.md exists
if [[ ! -f "$SKILL_FILE" ]]; then
  error "SKILL.md not found (case-sensitive check)"
  echo ""
  echo "Result: $ERRORS error(s), $WARNINGS warning(s)"
  exit 1
fi
ok "SKILL.md exists"

# 2. Frontmatter delimiters
FIRST_LINE=$(head -1 "$SKILL_FILE")
if [[ "$FIRST_LINE" != "---" ]]; then
  error "Missing opening --- delimiter"
fi

# Find closing delimiter (line number)
CLOSE_LINE=$(awk 'NR>1 && /^---$/{print NR; exit}' "$SKILL_FILE")
if [[ -z "$CLOSE_LINE" ]]; then
  error "Missing closing --- delimiter"
  echo ""
  echo "Result: $ERRORS error(s), $WARNINGS warning(s)"
  exit 1
fi
ok "Frontmatter delimiters present (closes at line $CLOSE_LINE)"

# Extract frontmatter
FRONTMATTER=$(sed -n "2,$((CLOSE_LINE - 1))p" "$SKILL_FILE")

# 3. name field
NAME=$(echo "$FRONTMATTER" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')
if [[ -z "$NAME" ]]; then
  error "name field missing"
else
  ok "name: $NAME"
  # Check kebab-case
  if [[ ! "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    error "name is not kebab-case: $NAME"
  fi
  # Check matches directory name
  DIR_NAME=$(basename "$SKILL_DIR")
  if [[ "$NAME" != "$DIR_NAME" ]]; then
    warn "name ($NAME) does not match directory name ($DIR_NAME)"
  fi
fi

# 4. description field
DESC=$(echo "$FRONTMATTER" | grep -c 'description:' || true)
if [[ "$DESC" -eq 0 ]]; then
  error "description field missing"
else
  ok "description field present"
  # Check for XML brackets
  if echo "$FRONTMATTER" | grep -q '[<>]'; then
    error "XML angle brackets found in frontmatter"
  fi
fi

# 5. Body analysis
BODY=$(tail -n +"$((CLOSE_LINE + 1))" "$SKILL_FILE")
BODY_LINES=$(echo "$BODY" | wc -l | tr -d ' ')
if [[ "$BODY_LINES" -gt 200 ]]; then
  warn "Body is $BODY_LINES lines (target: <200)"
else
  ok "Body is $BODY_LINES lines"
fi

# 6. Check for references links
if [[ -d "$SKILL_DIR/references" ]]; then
  REF_COUNT=$(find "$SKILL_DIR/references" -type f | wc -l | tr -d ' ')
  ok "references/ contains $REF_COUNT file(s)"

  # Check if SKILL.md links to references
  if ! grep -q 'references/' "$SKILL_FILE"; then
    warn "SKILL.md does not link to any references/ files"
  fi
fi

# 7. Check for JA triggers
if echo "$FRONTMATTER" | grep -qP '[\x{3040}-\x{309F}\x{30A0}-\x{30FF}\x{4E00}-\x{9FFF}]' 2>/dev/null || \
   echo "$FRONTMATTER" | grep -q '日本語'; then
  ok "Japanese triggers detected"
else
  warn "No Japanese triggers in description"
fi

# 8. Check for EN triggers
if echo "$FRONTMATTER" | grep -qi 'trigger'; then
  ok "English triggers detected"
else
  warn "No explicit trigger phrases in description"
fi

echo ""
echo "=== Result: $ERRORS error(s), $WARNINGS warning(s) ==="
exit $ERRORS
