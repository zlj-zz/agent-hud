# agent-hud

Lightweight dual-line statusline for **Claude Code**, **Cursor CLI**, and **pi**.

```
◆ Opus 4.6 ● max · ~/projects/my-project · git:main* · ⇄
Context ▰▰▰▰▰▱▱▱▱▱ 45% │ Usage ▰▰▰▱▱▱▱▱▱▱ 25% · 1h30m │ Hit 85% │ Cache ⏱ 4m 12s
```

## Quick install

```bash
git clone https://github.com/zlj-zz/agent-hud.git ~/projects/agent-hud
cd ~/projects/agent-hud
brew install luajit    # if needed (Claude/Cursor only)
./install.sh           # Claude + Cursor + pi
# ./install.sh --claude
# ./install.sh --cursor
# ./install.sh --pi
```

Then **restart** the Claude Code / Cursor CLI session, or run `/reload` in pi.

Coding agents: follow [AGENTS.md](AGENTS.md).

## Design

- Script-first, no build step
- **LuaJIT** core + vendored **hud.dkjson**
- Thin Bash wrappers for `statusLine.command`
- Deliberately smaller than claude-hud (no tools/agents/todos stream)

## Requirements

- `luajit` (e.g. `brew install luajit`)
- `git`
- `python3` (used by `install.sh` to update settings JSON)
- macOS / Linux

## What `./install.sh` changes

| Target | Script / Extension | Config |
|--------|--------|--------|
| Claude Code | `~/.claude/statusline.sh` | `~/.claude/settings.json` → `statusLine` |
| Cursor CLI | `~/.cursor/statusline.sh` | `$XDG_CONFIG_HOME/cursor/cli-config.json` (or `~/.cursor`, or `$CURSOR_CONFIG_DIR`) |
| pi | `~/.pi/agent/extensions/agent-hud/index.ts` | Auto-discovered (no config change needed) |

- Existing `statusLine` entries are **replaced**
- Default install writes a small wrapper that `exec`s this repo’s `bin/*.sh` (so `git pull` picks up updates)
- `./install.sh --link` symlinks instead
- Cursor: a custom statusline **replaces** the native footer (model/Auto-review row); this HUD re-adds useful bits such as `autorun` when present

## Preview

```bash
./bin/claude.sh --version   # agent-hud 0.1.0
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42},"effort":{"level":"high"}}' \
  | ./bin/claude.sh
```

## Config (`config.jsonc`)

JSONC (`//` and `/* */` comments). Comments are stripped before `dkjson` — no library change.

```jsonc
{
  // "en" | "zh"
  "language": "en",
  // "name" | "short" | "full"
  "cwd_style": "short",
  "bar_filled": "▰",
  "bar_empty": "▱",
  "show_effort": true,
  "show_prompt_cache": true,
  "prompt_cache_ttl": 300,
  "show_cache_hit": true,
  "show_autorun": true,
  "show_proxy": true,
  "week_threshold": 80
}
```

| Key | Default | Meaning |
|-----|---------|---------|
| `language` | `en` | `zh` / `en` labels |
| `cwd_style` | `short` | Path display: basename / `~/…` / absolute |
| `bar_filled` / `bar_empty` | `▰` / `▱` | Progress glyphs |
| `show_effort` | `true` | Model effort badge |
| `show_prompt_cache` | `true` | Cache TTL countdown via transcript tail scan |
| `prompt_cache_ttl` | `300` | Seconds (use `3600` for Max-style 1h) |
| `show_cache_hit` | `true` | Last-turn cache hit % from `current_usage` |
| `show_autorun` | `true` | Cursor only: muted-blue `autorun` badge when `autorun` is true |
| `show_proxy` | `true` | Agent `HTTP(S)_PROXY` → bright-blue `⇄` (`#6CB6FF`) |
| `week_threshold` | `80` | Show 7-day usage at/above this % |

Lookup: `$AGENT_HUD_CONFIG` → `~/.config/agent-hud/config.jsonc` → repo `config.jsonc`  
(also accepts plain `.json`)

## Update

```bash
cd ~/projects/agent-hud && git pull
# re-run ./install.sh only if the clone path changed
```

## Layout

```
bin/claude.sh / bin/cursor.sh   # set LUA_PATH → require("hud").main(...)
lib/hud/                        # self-contained Lua library package
  init.lua                      # exports main() + version
  version.lua                   # release version (0.1.0)
  dkjson.lua                    # vendored JSON (David Kolf)
  ansi.lua config.lua i18n.lua
  util.lua git.lua effort.lua
  cache.lua proxy.lua render.lua
extensions/pi/index.ts          # pi extension (TypeScript, native)
config.jsonc
install.sh
AGENTS.md
```

## License

MIT — see [LICENSE](LICENSE). Vendored `dkjson` remains under David Kolf’s terms (also MIT-compatible).

## Notes

- Usage bars need Claude subscriber `rate_limits` on stdin.
- `config.jsonc` changes apply on the next statusline refresh (no reinstall).
- Custom `ANTHROPIC_BASE_URL` is **not** treated as an HTTP proxy; only `HTTP(S)_PROXY` / `ALL_PROXY`.
- **pi**: the extension uses TypeScript natively (no luajit needed). Config is read from `~/.config/agent-hud/config.jsonc` or `$AGENT_HUD_CONFIG`. Cache TTL countdown is not available for pi (Claude-specific).
