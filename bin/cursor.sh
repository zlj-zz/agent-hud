#!/usr/bin/env bash
# Cursor CLI statusline entry → hud.main("cursor")
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export LUA_PATH="${ROOT}/lib/?.lua;${ROOT}/lib/?/init.lua;;"
exec luajit -e 'require("hud").main("cursor")'
