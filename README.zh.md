# agent-hud

给 **Claude Code** / **Cursor CLI** 用的轻量双行 statusline。

## 快速安装

```bash
git clone https://github.com/zlj-zz/agent-hud.git ~/projects/agent-hud
cd ~/projects/agent-hud
brew install luajit    # 如未安装
./install.sh           # 默认同时装 Claude + Cursor
# ./install.sh --claude
# ./install.sh --cursor
```

装完后请 **重启** Claude Code / Cursor CLI 会话。

交给 coding agent 安装时，请其遵循 [AGENTS.md](AGENTS.md)。

## 设计

- 脚本化，无构建
- **LuaJIT** 核心 + 内置 **dkjson.lua**
- Bash 只做薄入口
- 刻意不做 claude-hud 那种 tools/agents/todos 全量解析

版本号：`./bin/claude.sh --version`

## 依赖

- `luajit`（`brew install luajit`）
- `git`
- `python3`（`install.sh` 用来改 settings JSON）

## 安装会改什么

| 目标 | 脚本 | 配置 |
|------|------|------|
| Claude Code | `~/.claude/statusline.sh` | `~/.claude/settings.json` → `statusLine` |
| Cursor CLI | `~/.cursor/statusline.sh` | `$XDG_CONFIG_HOME/cursor/cli-config.json`（或 `~/.cursor` / `$CURSOR_CONFIG_DIR`） |

- 会 **覆盖** 已有 `statusLine`
- 默认写入指向本仓库 `bin/*.sh` 的 wrapper，`git pull` 即可更新
- Cursor：自定义 statusline 会 **替换** 原生 footer；本 HUD 会在有数据时补回 `autorun` 等信号

## 配置（`config.jsonc`）

支持 `//` / `/* */` 注释；运行时先剥注释再交给 `dkjson`。

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
  "show_cache_hit": true,
  "show_autorun": true,
  "show_proxy": true
}
```

- `Hit` / `命中`：上一轮 cache hit；`Cache ⏱`：transcript TTL 估算；开关独立
- `autorun`：仅 Cursor，`autorun: true` 时显示
- `⇄`：仅当 agent 进程/Claude `settings.env` 有 `HTTP(S)_PROXY`；自定义 `ANTHROPIC_BASE_URL`、仅系统 Clash **不算**

用户覆盖：`~/.config/agent-hud/config.jsonc`（或 `$AGENT_HUD_CONFIG`）。

## 预览

```bash
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42},"effort":{"level":"high"}}' | ./bin/claude.sh
```

## 更新

```bash
cd ~/projects/agent-hud && git pull
```

## 许可

MIT — 见 [LICENSE](LICENSE)。内置的 `dkjson` 仍按 David Kolf 的条款（与 MIT 兼容）。
