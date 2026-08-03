#!/usr/bin/env bash
# Cursor CLI statusline — dual-line colored bars
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
load_config

input=$(cat)

MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // "?"')
PARAM=$(printf '%s' "$input" | jq -r '.model.param_summary // empty')
MAX_MODE=$(printf '%s' "$input" | jq -r 'if .model.max_mode == true then "max" else empty end')
CWD=$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // empty')
CTX_PCT=$(printf '%s' "$input" | jq -r '(.context_window.used_percentage // empty) | if . == null or . == "" then empty else (tonumber | floor) end')
WORKTREE=$(printf '%s' "$input" | jq -r '.worktree.name // empty')
VIM=$(printf '%s' "$input" | jq -r '.vim.mode // empty')

PROJECT=$(project_name "$CWD")
EXTRA=$(git_segment "$CWD")

MODEL_EXTRA=""
[[ -n "$PARAM" ]] && MODEL_EXTRA+=" ${DIM}${PARAM}${RST}"
[[ -n "$MAX_MODE" ]] && MODEL_EXTRA+=" ${MAGENTA}${MAX_MODE}${RST}"
[[ -n "$WORKTREE" ]] && EXTRA+="  ${DIM}·${RST}  ${MAGENTA}wt:${CYAN}${WORKTREE}${RST}"
[[ -n "$VIM" ]] && EXTRA+="  ${DIM}·${RST}  ${DIM}${VIM}${RST}"

printf '%s◆%s %s%s%s%s  %s·%s  %s%s%s%s\n' \
  "$BOLD$CYAN" "$RST" \
  "$BOLD$CYAN" "$MODEL" "$RST" "$MODEL_EXTRA" \
  "$DIM" "$RST" \
  "$YELLOW" "$PROJECT" "$RST" \
  "$EXTRA"

if [[ -n "$CTX_PCT" ]]; then
  printf '%b\n' "$(print_context_segment "$CTX_PCT")"
else
  printf '%s%s%s\n' "$DIM" "$(t waiting)" "$RST"
fi
