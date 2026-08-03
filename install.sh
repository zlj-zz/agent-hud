#!/usr/bin/env bash
# Install Claude Code and/or Cursor CLI statuslines from this repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CLAUDE="${HOME}/.claude/statusline.sh"
TARGET_CURSOR="${HOME}/.cursor/statusline.sh"

cursor_config_path() {
  if [[ -n "${CURSOR_CONFIG_DIR:-}" ]]; then
    printf '%s/cli-config.json' "${CURSOR_CONFIG_DIR%/}"
  elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    printf '%s/cursor/cli-config.json' "${XDG_CONFIG_HOME%/}"
  else
    printf '%s/.cursor/cli-config.json' "$HOME"
  fi
}

usage() {
  cat <<EOF
Usage: ./install.sh [--claude] [--cursor] [--all] [--link]

  --claude   Install Claude Code statusline
  --cursor   Install Cursor CLI statusline
  --all      Install both (default if no target flags)
  --link     Symlink to this repo instead of copying a wrapper
  -h         Show help

Claude config : ~/.claude/settings.json
Cursor config : \$CURSOR_CONFIG_DIR or \$XDG_CONFIG_HOME/cursor or ~/.cursor
EOF
}

DO_CLAUDE=0
DO_CURSOR=0
USE_LINK=0
HAVE_TARGET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude) DO_CLAUDE=1; HAVE_TARGET=1; shift ;;
    --cursor) DO_CURSOR=1; HAVE_TARGET=1; shift ;;
    --all) DO_CLAUDE=1; DO_CURSOR=1; HAVE_TARGET=1; shift ;;
    --link) USE_LINK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if (( HAVE_TARGET == 0 )); then
  DO_CLAUDE=1
  DO_CURSOR=1
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

need luajit
need git

install_wrapper() {
  local name="$1" src="$2" dest="$3"
  mkdir -p "$(dirname "$dest")"
  if (( USE_LINK == 1 )); then
    ln -sfn "$src" "$dest"
    echo "linked $dest -> $src"
  else
    # Stable absolute path into this checkout so updates are one git pull away.
    cat >"$dest" <<EOF
#!/usr/bin/env bash
exec "$src" "\$@"
EOF
    chmod +x "$dest"
    echo "installed $dest (exec $src)"
  fi
}

set_claude_settings() {
  local settings="${HOME}/.claude/settings.json"
  mkdir -p "$(dirname "$settings")"
  python3 - "$settings" "$TARGET_CLAUDE" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
command = sys.argv[2]
data = {}
if path.exists():
    data = json.loads(path.read_text())
data["statusLine"] = {"type": "command", "command": command, "padding": 0}
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(f"updated {path} statusLine")
PY
}

set_cursor_settings() {
  local settings
  settings="$(cursor_config_path)"
  mkdir -p "$(dirname "$settings")"
  python3 - "$settings" "$TARGET_CURSOR" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
command = sys.argv[2]
if path.exists():
    data = json.loads(path.read_text())
else:
    data = {
        "version": 1,
        "permissions": {"allow": ["Shell(**)", "Read(**)"], "deny": []},
    }
data["statusLine"] = {"type": "command", "command": command, "padding": 0}
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(f"updated {path} statusLine")
PY
}

chmod +x "$ROOT/bin/claude.sh" "$ROOT/bin/cursor.sh" "$ROOT/lib/hud.lua"

if (( DO_CLAUDE == 1 )); then
  install_wrapper claude "$ROOT/bin/claude.sh" "$TARGET_CLAUDE"
  set_claude_settings
fi

if (( DO_CURSOR == 1 )); then
  install_wrapper cursor "$ROOT/bin/cursor.sh" "$TARGET_CURSOR"
  set_cursor_settings
fi

echo
echo "Done. Restart Claude Code / Cursor CLI sessions to see the new statusline."
echo "Preview:"
echo '  echo '"'"'{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42}}'"'"' | '"$ROOT/bin/claude.sh"
