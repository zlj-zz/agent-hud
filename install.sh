#!/usr/bin/env bash
# Install Claude Code, Cursor CLI, and/or pi statuslines from this repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CLAUDE="${HOME}/.claude/statusline.sh"
TARGET_CURSOR="${HOME}/.cursor/statusline.sh"
TARGET_PI="${HOME}/.pi/agent/extensions/agent-hud"

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
Usage: ./install.sh [--claude] [--cursor] [--pi] [--all] [--link]

  --claude   Install Claude Code statusline
  --cursor   Install Cursor CLI statusline
  --pi       Install pi coding agent statusline (extension)
  --all      Install all three (default if no target flags)
  --link     Symlink to this repo instead of copying a wrapper
  -h         Show help

Claude config : ~/.claude/settings.json
Cursor config : \$CURSOR_CONFIG_DIR or \$XDG_CONFIG_HOME/cursor or ~/.cursor
Pi config     : ~/.pi/agent/extensions/agent-hud/
EOF
}

DO_CLAUDE=0
DO_CURSOR=0
DO_PI=0
USE_LINK=0
HAVE_TARGET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude) DO_CLAUDE=1; HAVE_TARGET=1; shift ;;
    --cursor) DO_CURSOR=1; HAVE_TARGET=1; shift ;;
    --pi) DO_PI=1; HAVE_TARGET=1; shift ;;
    --all) DO_CLAUDE=1; DO_CURSOR=1; DO_PI=1; HAVE_TARGET=1; shift ;;
    --link) USE_LINK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if (( HAVE_TARGET == 0 )); then
  DO_CLAUDE=1
  DO_CURSOR=1
  DO_PI=1
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

if (( DO_CLAUDE == 1 )) || (( DO_CURSOR == 1 )); then
  need luajit
fi
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

install_pi_extension() {
  local src="$ROOT/extensions/pi/index.ts"
  local dest="$TARGET_PI"
  local dest_file="$dest/index.ts"
  mkdir -p "$dest"
  if (( USE_LINK == 1 )); then
    ln -sfn "$src" "$dest_file"
    echo "linked $dest_file -> $src"
  else
    cp "$src" "$dest_file"
    echo "installed $dest_file (copied from $src)"
  fi
}

chmod +x "$ROOT/bin/claude.sh" "$ROOT/bin/cursor.sh"

if (( DO_CLAUDE == 1 )); then
  install_wrapper claude "$ROOT/bin/claude.sh" "$TARGET_CLAUDE"
  set_claude_settings
fi

if (( DO_CURSOR == 1 )); then
  install_wrapper cursor "$ROOT/bin/cursor.sh" "$TARGET_CURSOR"
  set_cursor_settings
fi

if (( DO_PI == 1 )); then
  install_pi_extension
fi

echo
echo "Done."
if (( DO_CLAUDE == 1 )) || (( DO_CURSOR == 1 )); then
  echo "Restart Claude Code / Cursor CLI sessions to see the new statusline."
  echo "Preview:"
  echo '  echo '"'"'{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42}}'"'"' | '"$ROOT/bin/claude.sh"
fi
if (( DO_PI == 1 )); then
  echo "Run pi with /reload to load the agent-hud extension (or restart pi)."
fi
