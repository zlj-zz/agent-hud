#!/usr/bin/env bash
# Claude Code statusline — dual-line colored bars
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
load_config

input=$(cat)

MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // "?"')
CWD=$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // empty')
CTX_PCT=$(printf '%s' "$input" | jq -r '(.context_window.used_percentage // empty) | if . == null or . == "" then empty else (tonumber | floor) end')
USAGE_PCT=$(printf '%s' "$input" | jq -r '(.rate_limits.five_hour.used_percentage // empty) | if . == null or . == "" then empty else (tonumber | floor) end')
USAGE_RESET=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_PCT=$(printf '%s' "$input" | jq -r '(.rate_limits.seven_day.used_percentage // empty) | if . == null or . == "" then empty else (tonumber | floor) end')

PROJECT=$(project_name "$CWD")
GIT_PART=$(git_segment "$CWD")

print_identity_line "$MODEL" "$PROJECT" "$GIT_PART"

LINE2=""
if [[ -n "$CTX_PCT" ]]; then
  LINE2+=$(print_context_segment "$CTX_PCT")
fi

if [[ -n "$USAGE_PCT" ]]; then
  UC=$(usage_color "$USAGE_PCT")
  RESET_LABEL=$(rel_time "$USAGE_RESET")
  USAGE_LABEL=$(t usage)
  [[ -n "$LINE2" ]] && LINE2+="  ${DIM}│${RST}  "
  LINE2+=$(printf '%s%s%s %s%s%s %s%d%%%s' \
    "$DIM" "$USAGE_LABEL" "$RST" "$UC" "$(bar "$USAGE_PCT")" "$RST" "$UC$BOLD" "$USAGE_PCT" "$RST")
  if [[ -n "$RESET_LABEL" ]]; then
    LINE2+=$(printf ' %s· %s%s' "$DIM" "$RESET_LABEL" "$RST")
  fi
fi

if [[ -n "$WEEK_PCT" ]] && (( WEEK_PCT >= AH_WEEK_THRESHOLD )); then
  WC=$(usage_color "$WEEK_PCT")
  WEEK_LABEL=$(t week)
  [[ -n "$LINE2" ]] && LINE2+="  ${DIM}│${RST}  "
  LINE2+=$(printf '%s%s%s %s%s%s %s%d%%%s' \
    "$DIM" "$WEEK_LABEL" "$RST" "$WC" "$(bar "$WEEK_PCT")" "$RST" "$WC$BOLD" "$WEEK_PCT" "$RST")
fi

if [[ -n "$LINE2" ]]; then
  printf '%b\n' "$LINE2"
else
  printf '%s%s%s\n' "$DIM" "$(t waiting)" "$RST"
fi
