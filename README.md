# agent-hud

Lightweight dual-line statusline for **Claude Code** and **Cursor CLI**.

```
◆ Opus 4.6 ● max  ·  my-project  ·  git:main*
Context ▰▰▰▰▰▱▱▱▱▱  45%  │  Usage ▰▰▰▱▱▱▱▱▱▱  25% · 1h30m  │  Cache ⏱ 4m 12s
```

## Design

- Script-first, no build step
- **LuaJIT** core + vendored **hud.dkjson**
- Thin Bash wrappers for `statusLine.command`
- Deliberately smaller than claude-hud (no tools/agents/todos stream)

## Requirements

- `luajit` (e.g. `brew install luajit`)
- `git`
- macOS / Linux

## Install

```bash
cd ~/projects/agent-hud
./install.sh            # both
# ./install.sh --claude
# ./install.sh --cursor
```

| Target | Script | Config |
|--------|--------|--------|
| Claude Code | `~/.claude/statusline.sh` | `~/.claude/settings.json` |
| Cursor CLI | `~/.cursor/statusline.sh` | `$XDG_CONFIG_HOME/cursor/cli-config.json` (or `~/.cursor`) |

## Preview

```bash
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42},"effort":{"level":"high"}}' \
  | ./bin/claude.sh
```

## Config (`config.jsonc`)

JSONC (`//` and `/* */` comments). Comments are stripped before `dkjson` — no library change.

```jsonc
{
  // "en" | "zh"
  "language": "en",
  "bar_filled": "▰",
  "bar_empty": "▱",
  "show_effort": true,
  "show_prompt_cache": true,
  "prompt_cache_ttl": 300,
  "week_threshold": 80
}
```

| Key | Default | Meaning |
|-----|---------|---------|
| `language` | `en` | `zh` / `en` labels |
| `bar_filled` / `bar_empty` | `▰` / `▱` | Progress glyphs |
| `show_effort` | `true` | Model effort badge |
| `show_prompt_cache` | `true` | Cache countdown via transcript tail scan |
| `prompt_cache_ttl` | `300` | Seconds (use `3600` for Max-style 1h) |
| `week_threshold` | `80` | Show 7-day usage at/above this % |

Lookup: `$AGENT_HUD_CONFIG` → `~/.config/agent-hud/config.jsonc` → repo `config.jsonc`  
(also accepts plain `.json`)

## Layout

```
bin/claude.sh / bin/cursor.sh   # set LUA_PATH → require("hud").main(...)
lib/hud/                        # self-contained library package
  init.lua                      # exports main() + version
  version.lua                   # release version (0.1.0)
  dkjson.lua                    # vendored JSON (David Kolf)
  ansi.lua config.lua i18n.lua
  util.lua git.lua effort.lua
  cache.lua render.lua
config.jsonc
install.sh
```

```bash
./bin/claude.sh --version   # agent-hud 0.1.0
```

## License

MIT — see [LICENSE](LICENSE). Vendored `dkjson` remains under David Kolf’s terms (also MIT-compatible).

## Notes

- Cursor’s built-in footer is separate from this statusline.
- Usage bars need Claude subscriber `rate_limits` on stdin.
- Restart the CLI session after first install; `config.jsonc` changes apply on next refresh.
