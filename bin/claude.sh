#!/usr/bin/env bash
# Claude Code statusline entry → Lua core
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
exec luajit "$ROOT/lib/hud.lua" claude
