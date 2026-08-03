#!/usr/bin/env bash
# Claude Code statusline entry → hud.main("claude")
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export LUA_PATH="${ROOT}/lib/?.lua;${ROOT}/lib/?/init.lua;;"
if [[ "${1:-}" == "--version" || "${1:-}" == "-V" ]]; then
  exec luajit -e 'print("agent-hud " .. require("hud.version"))'
fi
exec luajit -e 'require("hud").main("claude")'
