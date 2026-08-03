#!/usr/bin/env bash
# Claude Code statusline entry → hud.main("claude")
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export LUA_PATH="${ROOT}/lib/?.lua;${ROOT}/lib/?/init.lua;;"
exec luajit -e 'require("hud").main("claude")'
