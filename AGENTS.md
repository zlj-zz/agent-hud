# Agent notes — agent-hud

Instructions for coding agents installing or updating this statusline for a user.
Supports: Claude Code, Cursor CLI, pi coding agent.

## Goal

Install or refresh **agent-hud** so Claude Code and/or Cursor CLI show the custom dual-line statusline.

## One-shot install

```bash
git clone https://github.com/zlj-zz/agent-hud.git ~/projects/agent-hud
cd ~/projects/agent-hud
command -v luajit >/dev/null || brew install luajit
command -v python3 >/dev/null || { echo "python3 required"; exit 1; }
./install.sh
```

Already cloned: `cd ~/projects/agent-hud && git pull && ./install.sh`

### Target flags

| Command | Effect |
|---------|--------|
| `./install.sh` | Claude + Cursor + pi (default) |
| `./install.sh --claude` | Claude Code only |
| `./install.sh --cursor` | Cursor CLI only |
| `./install.sh --pi` | pi coding agent only |
| `./install.sh --link` | Symlink wrappers to this repo instead of thin `exec` scripts |

## Dependencies

- `luajit`
- `git`
- `python3` (merges `statusLine` into settings JSON)
- macOS or Linux
- pi coding agent 1.0.x (pi target only; verified against 1.0.3)

## What install changes

| Target | Wrapper | Config key |
|--------|---------|------------|
| Claude Code | `~/.claude/statusline.sh` | pi | `~/.pi/agent/extensions/agent-hud/index.ts` | Auto-discovered by pi |
| `~/.claude/settings.json` → `statusLine` |
| Cursor CLI | `~/.cursor/statusline.sh` | `$CURSOR_CONFIG_DIR/cli-config.json` or `$XDG_CONFIG_HOME/cursor/cli-config.json` or `~/.cursor/cli-config.json` |

- **Overwrites** existing `statusLine` (does not merge multiple commands).
- Wrappers point at this checkout’s `bin/*.sh` by absolute path; `git pull` updates behavior without reinstall (re-run install if the repo moved).

## Verify

```bash
./bin/claude.sh --version
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42}}' | ./bin/claude.sh
```

For pi, the extension shows a dual-line widget below the editor after `/reload` or pi restart.

Tell the user to **restart** the Claude Code / Cursor CLI session after install. For pi, run `/reload` or restart pi.

## Config

- Default: repo `config.jsonc`
- User override: `~/.config/agent-hud/config.jsonc` or `$AGENT_HUD_CONFIG`
- Do not commit the user’s private override file into this repo

## Do / don’t

- Do: install deps if missing, run `install.sh`, preview, explain restart
- Don’t: force-push, change git config, commit unrelated trees, or assume Cursor config is always `~/.cursor/cli-config.json` (respect XDG)
- Don’t: treat custom `ANTHROPIC_BASE_URL` as HTTP proxy; proxy badge only follows `HTTP(S)_PROXY` / `ALL_PROXY`
