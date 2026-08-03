# agent-hud

给 **Claude Code** 和 **Cursor CLI** 用的双行彩色 statusline。

```
◆ Opus 4.6  ·  my-project  ·  git:main*
上下文 ▰▰▰▰▰▱▱▱▱▱  45%  │  用量 ▰▰▰▱▱▱▱▱▱▱  25% · 1h30m
```

## 依赖

`bash`、`jq`、`git`

## 安装

```bash
cd ~/projects/agent-hud
./install.sh            # 两个都装
# ./install.sh --claude
# ./install.sh --cursor
```

配置写入位置：

- Claude：`~/.claude/settings.json`
- Cursor：优先 `$XDG_CONFIG_HOME/cursor/cli-config.json`（你这台机器就是这里）

安装后会生成指向本仓库的包装脚本，之后 `git pull` 即可更新。

## 预览

```bash
echo '{"model":{"display_name":"Opus"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42}}' | ./bin/claude.sh
```

改完配置后**重启** Claude Code / Cursor CLI 会话。
