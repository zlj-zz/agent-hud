# agent-hud

给 **Claude Code** / **Cursor CLI** 用的轻量双行 statusline。

## 设计

- 脚本化，无构建
- **LuaJIT** 核心 + 内置 **dkjson.lua**
- Bash 只做薄入口
- 刻意不做 claude-hud 那种 tools/agents/todos 全量解析

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
  "bar_filled": "▰",
  "bar_empty": "▱",
  "show_effort": true,
  "show_prompt_cache": true,
  "prompt_cache_ttl": 300
}
```

用户覆盖：`~/.config/agent-hud/config.jsonc`（或 `$AGENT_HUD_CONFIG`）。

## 预览

```bash
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42},"effort":{"level":"high"}}' | ./bin/claude.sh
```
