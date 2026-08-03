#!/usr/bin/env bash
# Cursor CLI statusline entry → Lua core
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
exec luajit "$ROOT/lib/hud.lua" cursor
