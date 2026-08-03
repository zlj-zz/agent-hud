# agent-hud

Small dual-line statusline scripts for **Claude Code** and **Cursor CLI**.

```
◆ Opus 4.6  ·  my-project  ·  git:main*
上下文 ▰▰▰▰▰▱▱▱▱▱  45%  │  用量 ▰▰▰▱▱▱▱▱▱▱  25% · 1h30m
```

## Requirements

- `bash`, `jq`, `git`
- macOS/Linux (Homebrew `jq` path is included)

## Install

```bash
git clone <your-remote-url> ~/projects/agent-hud
cd ~/projects/agent-hud
./install.sh            # both
# ./install.sh --claude
# ./install.sh --cursor
# ./install.sh --link   # symlink instead of wrapper
```

`install.sh` writes:

| Target | Script | Config |
|--------|--------|--------|
| Claude Code | `~/.claude/statusline.sh` | `~/.claude/settings.json` |
| Cursor CLI | `~/.cursor/statusline.sh` | `$CURSOR_CONFIG_DIR/cli-config.json`, else `$XDG_CONFIG_HOME/cursor/cli-config.json`, else `~/.cursor/cli-config.json` |

Wrappers point back into this repo, so `git pull` updates the live statusline.

## Preview

```bash
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42}}' \
  | ./bin/claude.sh

echo '{"model":{"display_name":"Composer","param_summary":"(Thinking)"},"cwd":"'"$PWD"'","context_window":{"used_percentage":38}}' \
  | ./bin/cursor.sh
```

## Config (`config.jsonl`)

One JSON object per line. First setting is language (bilingual `zh` / `en`):

```jsonl
{"language":"zh"}
```

Optional later lines, for example:

```jsonl
{"language":"en"}
{"bar_filled":"█"}
{"bar_empty":"░"}
{"week_threshold":80}
```

Progress bar characters:

| Key | Default | Meaning |
|-----|---------|---------|
| `bar_filled` | `▰` | Filled segment |
| `bar_empty` | `▱` | Empty segment |

Lookup order:

1. `$AGENT_HUD_CONFIG`
2. `$XDG_CONFIG_HOME/agent-hud/config.jsonl` or `~/.config/agent-hud/config.jsonl`
3. `~/.agent-hud/config.jsonl`
4. repo `config.jsonl`

## Layout

```
bin/claude.sh   # Claude Code (model / git / context / usage)
bin/cursor.sh   # Cursor CLI  (model / git / context / worktree / vim)
lib/common.sh   # shared colors + bars + i18n
config.jsonl    # defaults (language, …)
install.sh
```

## Notes

- Cursor’s built-in footer (`Auto · 43%`) is separate; this statusline renders above the prompt.
- Claude usage bars only appear when stdin includes subscriber `rate_limits`.
- Restart the CLI session after install.
