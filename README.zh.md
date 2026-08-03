# agent-hud

给 **Claude Code** / **Cursor CLI** 用的轻量双行 statusline。

## 设计

- 脚本化，无构建
- **LuaJIT** 核心 + 内置 **dkjson.lua**
- Bash 只做薄入口
- 刻意不做 claude-hud 那种 tools/agents/todos 全量解析

版本号在 `lib/hud/version.lua`，可用 `./bin/claude.sh --version` 查看。

`Hit` / `命中`：上一轮 `cache_read / (input + creation + read)`；`Cache ⏱`：按 transcript 估 TTL。两者独立开关。

## 依赖

- `luajit`（`brew install luajit`）
- `git`

## 安装

```bash
cd ~/projects/agent-hud
./install.sh
```

## 配置（`config.jsonc`）

支持 `//` / `/* */` 注释；运行时先剥注释再交给 `dkjson`，不用换库。

```jsonc
{
  // "en" | "zh"
  "language": "zh",
  // "name" 仅目录名 | "short" ~/… | "full" 绝对路径
  "cwd_style": "short",
  "bar_filled": "▰",
  "bar_empty": "▱",
  "show_effort": true,
  "show_prompt_cache": true,
  "prompt_cache_ttl": 300,
  "show_cache_hit": true
}
```

用户覆盖：`~/.config/agent-hud/config.jsonc`（或 `$AGENT_HUD_CONFIG`）。

## 预览

```bash
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42},"effort":{"level":"high"}}' | ./bin/claude.sh
```

## 许可

MIT — 见 [LICENSE](LICENSE)。内置的 `dkjson` 仍按 David Kolf 的条款（与 MIT 兼容）。
