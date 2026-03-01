#!/bin/bash
# Claude Code custom status line (dual-line: ccusage + custom)
# stdin: JSON from Claude Code | stdout: multi-line status bar

INPUT=$(cat)

# ===== Line 1: ccusage (pass-through) =====
LINE1=$(echo "$INPUT" | bun x ccusage statusline 2>/dev/null)

# ===== Line 2: custom status line =====

# --- Parse JSON (single jq call) ---
eval "$(echo "$INPUT" | jq -r '
  @sh "SESSION_ID=\(.session_id // "")",
  @sh "CWD=\(.cwd // "")",
  @sh "USED_PCT=\(.context_window.used_percentage // 0)",
  @sh "MODEL=\(.model.display_name // "")",
  @sh "DURATION_MS=\(.cost.total_duration_ms // 0)",
  @sh "INPUT_TOKENS=\(.context_window.total_input_tokens // 0)",
  @sh "OUTPUT_TOKENS=\(.context_window.total_output_tokens // 0)"
')"

# --- Colors ---
RST=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
GRN=$'\033[32m'
YLW=$'\033[33m'
BLU=$'\033[34m'
MAG=$'\033[35m'
RED=$'\033[31m'
GRY=$'\033[90m'
BCYN=$'\033[1;36m'
BYLW=$'\033[1;33m'

# --- Session name ---
NAME=""
if [ -n "$SESSION_ID" ]; then
  STATE_FILE="/tmp/cc-status-${SESSION_ID}.json"
  if [ -f "$STATE_FILE" ]; then
    NAME=$(jq -r '.name // empty' "$STATE_FILE" 2>/dev/null)
  fi
fi
[ -z "$NAME" ] && NAME=$(basename "${CWD:-$(pwd)}")

# --- Path ---
SHORT_PATH="${CWD/#$HOME/~}"
HOST_NAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)

# --- Model (strip "Claude " prefix, keep version: "Opus 4.6") ---
M_DISPLAY="${MODEL#Claude }"
case "$MODEL" in
  *Opus*)   M_COLOR="$MAG" ;;
  *Sonnet*) M_COLOR="$BLU" ;;
  *Haiku*)  M_COLOR="$GRN" ;;
  *)        M_COLOR="$GRY" ;;
esac
M_SHORT="${M_DISPLAY:-...}"

# --- Context bar (10 segments) ---
USED_INT=${USED_PCT%.*}
USED_INT=${USED_INT:-0}
FILLED=$((USED_INT / 10))
EMPTY=$((10 - FILLED))

if [ "$USED_INT" -lt 50 ]; then
  BAR_COLOR="$GRN"
elif [ "$USED_INT" -lt 75 ]; then
  BAR_COLOR="$YLW"
else
  BAR_COLOR="$RED"
fi

BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="▓"; done
EBAR=""
for ((i=0; i<EMPTY; i++)); do EBAR+="░"; done

# --- Tokens (compact) ---
fmt_tok() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    printf "%.1fM" "$(echo "scale=1; $n/1000000" | bc)"
  elif [ "$n" -ge 1000 ]; then
    printf "%.1fk" "$(echo "scale=1; $n/1000" | bc)"
  else
    printf "%d" "$n"
  fi
}
TOK_IN=$(fmt_tok "$INPUT_TOKENS")
TOK_OUT=$(fmt_tok "$OUTPUT_TOKENS")

# --- Duration ---
DUR_S=$((DURATION_MS / 1000))
DUR_FMT=$(printf '%d:%02d' $((DUR_S / 60)) $((DUR_S % 60)))

# --- Separator ---
SEP="${GRY}|${RST}"

# --- Build Line 2 ---
LINE2="${BCYN}${NAME}${RST} ${SEP} ${DIM}${HOST_NAME}:${SHORT_PATH}${RST} ${SEP} ${M_COLOR}${BOLD}${M_SHORT}${RST} ${SEP} ${BAR_COLOR}${BAR}${GRY}${EBAR}${RST} ${USED_INT}% ${SEP} ${GRY}${TOK_IN}in ${TOK_OUT}out${RST} ${SEP} ${DIM}${DUR_FMT}${RST}"

# ===== Output =====
# Line 1: ccusage (if available), Line 2: custom
if [ -n "$LINE1" ]; then
  echo "$LINE1"
fi
echo -e "$LINE2"
