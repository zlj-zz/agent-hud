#!/usr/bin/env bash
# Shared helpers for Claude Code / Cursor CLI statuslines.

# Ensure Homebrew tools are visible when the host spawns without a login PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

RST=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
GREEN=$'\033[32m'
BRIGHT_BLUE=$'\033[94m'
BRIGHT_MAGENTA=$'\033[95m'
RED=$'\033[31m'

# Defaults — overridden by config.jsonl
AH_LANGUAGE="zh"
AH_WEEK_THRESHOLD=80

# Resolve config file: env > user override > repo config.jsonl
config_path() {
  if [[ -n "${AGENT_HUD_CONFIG:-}" ]]; then
    printf '%s' "$AGENT_HUD_CONFIG"
    return 0
  fi
  if [[ -n "${XDG_CONFIG_HOME:-}" && -f "${XDG_CONFIG_HOME%/}/agent-hud/config.jsonl" ]]; then
    printf '%s' "${XDG_CONFIG_HOME%/}/agent-hud/config.jsonl"
    return 0
  fi
  if [[ -f "${HOME}/.config/agent-hud/config.jsonl" ]]; then
    printf '%s' "${HOME}/.config/agent-hud/config.jsonl"
    return 0
  fi
  if [[ -f "${HOME}/.agent-hud/config.jsonl" ]]; then
    printf '%s' "${HOME}/.agent-hud/config.jsonl"
    return 0
  fi
  printf '%s' "${ROOT}/config.jsonl"
}

# Each JSONL line is one setting object. Supported keys (first occurrence wins):
#   {"language":"zh"|"en"}
#   {"week_threshold":80}
load_config() {
  local path line lang thr
  path="$(config_path)"
  [[ -f "$path" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" == \#* ]] && continue

    lang=$(printf '%s' "$line" | jq -r 'if has("language") then .language elif .key == "language" then (.value // empty) else empty end' 2>/dev/null || true)
    if [[ -n "$lang" && "$lang" != "null" ]]; then
      case "$lang" in
        zh|zh-Hans|zh-CN|cn) AH_LANGUAGE="zh" ;;
        en|english) AH_LANGUAGE="en" ;;
      esac
    fi

    thr=$(printf '%s' "$line" | jq -r 'if has("week_threshold") then .week_threshold elif .key == "week_threshold" then (.value // empty) else empty end' 2>/dev/null || true)
    if [[ -n "$thr" && "$thr" != "null" ]]; then
      if [[ "$thr" =~ ^[0-9]+$ ]]; then
        AH_WEEK_THRESHOLD="$thr"
      fi
    fi
  done <"$path"
}

# Bilingual label lookup
t() {
  local key="$1"
  case "$AH_LANGUAGE:$key" in
    zh:context) printf '上下文' ;;
    en:context) printf 'Context' ;;
    zh:usage) printf '用量' ;;
    en:usage) printf 'Usage' ;;
    zh:week) printf '7天' ;;
    en:week) printf '7d' ;;
    zh:waiting) printf '等待会话数据…' ;;
    en:waiting) printf 'Waiting for session data…' ;;
    *) printf '%s' "$key" ;;
  esac
}

bar() {
  local pct="${1:-0}" width="${2:-10}"
  local filled=$(( (pct * width + 50) / 100 ))
  (( filled > width )) && filled=$width
  (( filled < 0 )) && filled=0
  local empty=$(( width - filled )) out="" i
  for (( i = 0; i < filled; i++ )); do out+="▰"; done
  for (( i = 0; i < empty; i++ )); do out+="▱"; done
  printf '%s' "$out"
}

context_color() {
  local pct="${1:-0}"
  if (( pct >= 85 )); then printf '%s' "$RED"
  elif (( pct >= 70 )); then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

usage_color() {
  local pct="${1:-0}"
  if (( pct >= 90 )); then printf '%s' "$RED"
  elif (( pct >= 75 )); then printf '%s' "$BRIGHT_MAGENTA"
  else printf '%s' "$BRIGHT_BLUE"
  fi
}

rel_time() {
  local ts="$1"
  [[ -z "$ts" || "$ts" == "null" ]] && return 0
  local now diff mins hours days rem_h rem_m
  now=$(date +%s)
  if (( ts > 1000000000000 )); then ts=$(( ts / 1000 )); fi
  diff=$(( ts - now ))
  (( diff <= 0 )) && return 0
  mins=$(( (diff + 59) / 60 ))
  if (( mins < 60 )); then
    printf '%sm' "$mins"
  elif (( mins < 1440 )); then
    hours=$(( mins / 60 )); rem_m=$(( mins % 60 ))
    if (( rem_m > 0 )); then printf '%sh%sm' "$hours" "$rem_m"
    else printf '%sh' "$hours"
    fi
  else
    days=$(( mins / 1440 )); rem_h=$(( (mins % 1440) / 60 ))
    if (( rem_h > 0 )); then printf '%sd%sh' "$days" "$rem_h"
    else printf '%sd' "$days"
    fi
  fi
}

project_name() {
  local cwd="$1"
  if [[ -n "$cwd" ]]; then printf '%s' "${cwd##*/}"
  else printf '?'
  fi
}

git_segment() {
  local cwd="$1"
  [[ -z "$cwd" ]] && return 0
  git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local branch dirty=""
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  if [[ -z "$branch" ]]; then
    branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo detached)
  fi
  if ! git -C "$cwd" diff --quiet 2>/dev/null || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
    dirty="*"
  elif [[ -n "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]]; then
    dirty="*"
  fi
  printf '  %s·%s  %sgit:%s%s%s%s%s' \
    "$DIM" "$RST" "$MAGENTA" "$CYAN" "$branch" "$YELLOW" "$dirty" "$RST"
}

print_identity_line() {
  local model="$1" project="$2" extra="${3:-}"
  printf '%s◆%s %s%s%s  %s·%s  %s%s%s%s\n' \
    "$BOLD$CYAN" "$RST" \
    "$BOLD$CYAN" "$model" "$RST" \
    "$DIM" "$RST" \
    "$YELLOW" "$project" "$RST" \
    "$extra"
}

print_context_segment() {
  local pct="$1"
  local cc label
  cc=$(context_color "$pct")
  label=$(t context)
  printf '%s%s%s %s%s%s %s%d%%%s' \
    "$DIM" "$label" "$RST" "$cc" "$(bar "$pct")" "$RST" "$cc$BOLD" "$pct" "$RST"
}
