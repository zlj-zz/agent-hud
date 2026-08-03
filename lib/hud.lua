#!/usr/bin/env luajit
-- agent-hud core: lightweight dual-line statusline for Claude Code / Cursor CLI.
-- Usage: hud.lua <claude|cursor>   (JSON on stdin)

local function script_root()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    local dir = src:sub(2):match("(.*/)") or "./"
    dir = dir:gsub("/lib/$", "/")
    return (dir:gsub("/$", ""))
  end
  return "."
end

local ROOT = script_root()
package.path = ROOT .. "/lib/?.lua;" .. package.path

local json = require("dkjson")

local RST = "\27[0m"
local DIM = "\27[2m"
local BOLD = "\27[1m"
local CYAN = "\27[36m"
local YELLOW = "\27[33m"
local MAGENTA = "\27[35m"
local GREEN = "\27[32m"
local BRIGHT_BLUE = "\27[94m"
local BRIGHT_MAGENTA = "\27[95m"
local RED = "\27[31m"

local cfg = {
  language = "en",
  week_threshold = 80,
  bar_filled = "▰",
  bar_empty = "▱",
  show_effort = true,
  show_prompt_cache = true,
  prompt_cache_ttl = 300,
}

local labels = {
  zh = {
    context = "上下文",
    usage = "用量",
    week = "7天",
    waiting = "等待会话数据…",
    cache = "缓存",
    expired = "已过期",
  },
  en = {
    context = "Context",
    usage = "Usage",
    week = "7d",
    waiting = "Waiting for session data…",
    cache = "Cache",
    expired = "expired",
  },
}

local function t(key)
  local pack = labels[cfg.language] or labels.en
  return pack[key] or key
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_bool(v)
  if type(v) == "boolean" then return v end
  if type(v) == "number" then return v ~= 0 end
  if type(v) ~= "string" then return nil end
  local s = v:lower()
  if s == "true" or s == "1" or s == "yes" or s == "on" then return true end
  if s == "false" or s == "0" or s == "no" or s == "off" then return false end
  return nil
end

local function config_path()
  local env = os.getenv("AGENT_HUD_CONFIG")
  if env and env ~= "" then return env end
  local candidates = {}
  local xdg = os.getenv("XDG_CONFIG_HOME")
  if xdg and xdg ~= "" then
    local base = xdg:gsub("/$", "") .. "/agent-hud/"
    candidates[#candidates + 1] = base .. "config.jsonc"
    candidates[#candidates + 1] = base .. "config.json"
  end
  local home = os.getenv("HOME") or ""
  for _, base in ipairs({
    home .. "/.config/agent-hud/",
    home .. "/.agent-hud/",
    ROOT .. "/",
  }) do
    candidates[#candidates + 1] = base .. "config.jsonc"
    candidates[#candidates + 1] = base .. "config.json"
  end
  for _, p in ipairs(candidates) do
    local f = io.open(p, "r")
    if f then f:close(); return p end
  end
  return ROOT .. "/config.jsonc"
end

-- Strip // and /* */ comments while preserving string contents.
local function strip_jsonc(src)
  local out = {}
  local i, n = 1, #src
  local state = "code" -- code | line | block | string | escape
  while i <= n do
    local c = src:sub(i, i)
    local n1 = src:sub(i + 1, i + 1)
    if state == "code" then
      if c == '"' then
        state = "string"
        out[#out + 1] = c
        i = i + 1
      elseif c == "/" and n1 == "/" then
        state = "line"
        i = i + 2
      elseif c == "/" and n1 == "*" then
        state = "block"
        i = i + 2
      else
        out[#out + 1] = c
        i = i + 1
      end
    elseif state == "line" then
      if c == "\n" then
        state = "code"
        out[#out + 1] = c
      end
      i = i + 1
    elseif state == "block" then
      if c == "*" and n1 == "/" then
        state = "code"
        i = i + 2
      else
        -- keep newlines so line numbers stay roughly stable for errors
        if c == "\n" then out[#out + 1] = c end
        i = i + 1
      end
    elseif state == "string" then
      out[#out + 1] = c
      if c == "\\" then
        state = "escape"
      elseif c == '"' then
        state = "code"
      end
      i = i + 1
    elseif state == "escape" then
      out[#out + 1] = c
      state = "string"
      i = i + 1
    end
  end
  return table.concat(out)
end

local function apply_config_obj(obj)
  if type(obj) ~= "table" then return end
  local function val(k)
    return obj[k]
  end

  local lang = val("language")
  if type(lang) == "string" then
    lang = lang:lower()
    if lang == "zh" or lang == "zh-hans" or lang == "zh-cn" or lang == "cn" then
      cfg.language = "zh"
    elseif lang == "en" or lang == "english" then
      cfg.language = "en"
    end
  end

  local thr = val("week_threshold")
  if type(thr) == "number" and thr >= 0 then
    cfg.week_threshold = math.floor(thr)
  elseif type(thr) == "string" and thr:match("^%d+$") then
    cfg.week_threshold = tonumber(thr)
  end

  local filled = val("bar_filled")
  if type(filled) == "string" and filled ~= "" then cfg.bar_filled = filled end
  local empty = val("bar_empty")
  if type(empty) == "string" and empty ~= "" then cfg.bar_empty = empty end

  local se = parse_bool(val("show_effort"))
  if se ~= nil then cfg.show_effort = se end
  local sc = parse_bool(val("show_prompt_cache"))
  if sc ~= nil then cfg.show_prompt_cache = sc end

  local ttl = val("prompt_cache_ttl")
  if type(ttl) == "number" and ttl > 0 then
    cfg.prompt_cache_ttl = math.floor(ttl)
  elseif type(ttl) == "string" and ttl:match("^%d+$") and tonumber(ttl) > 0 then
    cfg.prompt_cache_ttl = tonumber(ttl)
  end
end

local function load_config()
  local path = config_path()
  local f = io.open(path, "r")
  if not f then return end
  local raw = f:read("*a") or ""
  f:close()

  local cleaned = strip_jsonc(raw)
  local obj = json.decode(cleaned)
  if type(obj) == "table" then
    apply_config_obj(obj)
  end
end

local function read_stdin()
  local chunks = {}
  while true do
    local chunk = io.read(4096)
    if not chunk then break end
    chunks[#chunks + 1] = chunk
  end
  return table.concat(chunks)
end

local function floor_pct(v)
  if type(v) ~= "number" then return nil end
  if v ~= v then return nil end -- NaN
  local n = math.floor(v)
  if n < 0 then n = 0 end
  if n > 100 then n = 100 end
  return n
end

local function bar(pct, width)
  width = width or 10
  pct = pct or 0
  local filled = math.floor((pct * width + 50) / 100)
  if filled > width then filled = width end
  if filled < 0 then filled = 0 end
  local empty = width - filled
  return string.rep(cfg.bar_filled, filled) .. string.rep(cfg.bar_empty, empty)
end

local function context_color(pct)
  if pct >= 85 then return RED end
  if pct >= 70 then return YELLOW end
  return GREEN
end

local function usage_color(pct)
  if pct >= 90 then return RED end
  if pct >= 75 then return BRIGHT_MAGENTA end
  return BRIGHT_BLUE
end

local function rel_time(ts)
  if type(ts) ~= "number" then return nil end
  if ts > 1e12 then ts = math.floor(ts / 1000) end
  local now = os.time()
  local diff = ts - now
  if diff <= 0 then return nil end
  local mins = math.ceil(diff / 60)
  if mins < 60 then return string.format("%dm", mins) end
  if mins < 1440 then
    local hours = math.floor(mins / 60)
    local rem = mins % 60
    if rem > 0 then return string.format("%dh%dm", hours, rem) end
    return string.format("%dh", hours)
  end
  local days = math.floor(mins / 1440)
  local rem_h = math.floor((mins % 1440) / 60)
  if rem_h > 0 then return string.format("%dd%dh", days, rem_h) end
  return string.format("%dd", days)
end

local function project_name(cwd)
  if not cwd or cwd == "" then return "?" end
  return cwd:match("([^/]+)$") or cwd
end

local function run_git(cwd, args)
  if not cwd or cwd == "" then return nil end
  local cmd = string.format(
    "git -C %q %s 2>/dev/null",
    cwd,
    args
  )
  local p = io.popen(cmd)
  if not p then return nil end
  local out = p:read("*a") or ""
  local ok = p:close()
  if not ok then return nil end
  out = trim(out)
  if out == "" then return nil end
  return out
end

local function git_segment(cwd)
  if not cwd or cwd == "" then return "" end
  if not run_git(cwd, "rev-parse --is-inside-work-tree") then return "" end
  local branch = run_git(cwd, "branch --show-current")
  if not branch then
    branch = run_git(cwd, "rev-parse --short HEAD") or "detached"
  end
  local dirty = ""
  -- diff --quiet exits 1 when dirty; io.popen close reflects that
  local function dirty_check(args)
    local cmd = string.format("git -C %q %s >/dev/null 2>&1; echo $?", cwd, args)
    local p = io.popen(cmd)
    if not p then return false end
    local code = trim(p:read("*a") or "")
    p:close()
    return code ~= "0"
  end
  if dirty_check("diff --quiet") or dirty_check("diff --cached --quiet") then
    dirty = "*"
  else
    local untracked = run_git(cwd, "ls-files --others --exclude-standard")
    if untracked then dirty = "*" end
  end
  return string.format("  %s·%s  %sgit:%s%s%s%s%s", DIM, RST, MAGENTA, CYAN, branch, YELLOW, dirty, RST)
end

local function effort_symbol(level)
  level = tostring(level or ""):lower()
  if level == "low" then return "○" end
  if level == "medium" or level == "med" then return "◔" end
  if level == "high" then return "◑" end
  if level == "xhigh" then return "◕" end
  if level == "max" then return "●" end
  return "◉"
end

local function effort_level(payload)
  local e = payload.effort
  if type(e) == "string" and e ~= "" then return e end
  if type(e) == "table" and type(e.level) == "string" and e.level ~= "" then
    return e.level
  end
  return nil
end

local function effort_segment(level)
  if not cfg.show_effort or not level then return "" end
  return string.format(" %s%s%s %s%s%s", MAGENTA, effort_symbol(level), RST, DIM, level, RST)
end

local function parse_iso_to_epoch(ts)
  if type(ts) ~= "string" or ts == "" then return nil end
  -- 2026-08-03T04:23:24.756Z
  local y, mo, d, h, mi, s = ts:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return nil end
  return os.time({
    year = tonumber(y),
    month = tonumber(mo),
    day = tonumber(d),
    hour = tonumber(h),
    min = tonumber(mi),
    sec = tonumber(s),
    isdst = false,
  })
  -- Note: treats timestamp as local-ish; for HUD countdown this is acceptable.
end

local function last_assistant_epoch(transcript)
  if not transcript or transcript == "" then return nil end
  local f = io.open(transcript, "rb")
  if not f then return nil end
  local size = f:seek("end")
  local max_bytes = 512 * 1024
  local start = 0
  if size > max_bytes then start = size - max_bytes end
  f:seek("set", start)
  local data = f:read("*a") or ""
  f:close()
  if start > 0 then
    local nl = data:find("\n", 1, true)
    if nl then data = data:sub(nl + 1) end
  end
  local last_ts = nil
  for line in data:gmatch("[^\r\n]+") do
    if line:find('"type"%s*:%s*"assistant"', 1) or line:find('"type":"assistant"', 1, true) then
      local obj = json.decode(line)
      if type(obj) == "table" and obj.type == "assistant" and type(obj.timestamp) == "string" then
        last_ts = obj.timestamp
      end
    end
  end
  if not last_ts then return nil end
  return parse_iso_to_epoch(last_ts)
end

local function format_cache_countdown(remaining)
  if remaining <= 0 then return t("expired") end
  local hours = math.floor(remaining / 3600)
  local mins = math.floor((remaining % 3600) / 60)
  local secs = remaining % 60
  if hours > 0 then
    return string.format("%dh %dm %ds", hours, mins, secs)
  end
  return string.format("%dm %ds", mins, secs)
end

local function prompt_cache_segment(transcript)
  if not cfg.show_prompt_cache then return "" end
  local epoch = last_assistant_epoch(transcript)
  if not epoch then return "" end
  local now = os.time()
  local ttl = cfg.prompt_cache_ttl
  local remaining = epoch + ttl - now
  local warn = math.floor(ttl / 5)
  if warn < 60 then warn = 60 end
  if warn > ttl then warn = ttl end
  local color = GREEN
  if remaining <= 0 then
    color = DIM
  elseif remaining <= warn then
    color = YELLOW
  end
  return string.format("%s%s%s %s⏱ %s%s", DIM, t("cache"), RST, color, format_cache_countdown(remaining), RST)
end

local function print_context_segment(pct)
  local cc = context_color(pct)
  return string.format("%s%s%s %s%s%s %s%d%%%s", DIM, t("context"), RST, cc, bar(pct), RST, cc .. BOLD, pct, RST)
end

local function join_parts(parts)
  local out = {}
  for _, p in ipairs(parts) do
    if p and p ~= "" then out[#out + 1] = p end
  end
  return table.concat(out, "  " .. DIM .. "│" .. RST .. "  ")
end

local function render_claude(payload)
  local model = (payload.model and payload.model.display_name) or "?"
  local cwd = payload.cwd or (payload.workspace and payload.workspace.current_dir) or ""
  local transcript = payload.transcript_path or ""
  local cw = payload.context_window or {}
  local ctx = floor_pct(cw.used_percentage)
  local rl = payload.rate_limits or {}
  local five = rl.five_hour or {}
  local seven = rl.seven_day or {}
  local usage = floor_pct(five.used_percentage)
  local week = floor_pct(seven.used_percentage)
  local effort = effort_level(payload)

  local line1 = string.format(
    "%s◆%s %s%s%s%s  %s·%s  %s%s%s%s",
    BOLD .. CYAN, RST,
    BOLD .. CYAN, model, RST, effort_segment(effort),
    DIM, RST,
    YELLOW, project_name(cwd), RST,
    git_segment(cwd)
  )

  local parts = {}
  if ctx then parts[#parts + 1] = print_context_segment(ctx) end
  if usage then
    local uc = usage_color(usage)
    local seg = string.format("%s%s%s %s%s%s %s%d%%%s", DIM, t("usage"), RST, uc, bar(usage), RST, uc .. BOLD, usage, RST)
    local reset = rel_time(five.resets_at)
    if reset then
      seg = seg .. string.format(" %s· %s%s", DIM, reset, RST)
    end
    parts[#parts + 1] = seg
  end
  if week and week >= cfg.week_threshold then
    local wc = usage_color(week)
    parts[#parts + 1] = string.format("%s%s%s %s%s%s %s%d%%%s", DIM, t("week"), RST, wc, bar(week), RST, wc .. BOLD, week, RST)
  end
  local cache = prompt_cache_segment(transcript)
  if cache ~= "" then parts[#parts + 1] = cache end

  local line2 = join_parts(parts)
  if line2 == "" then line2 = DIM .. t("waiting") .. RST end
  return line1 .. "\n" .. line2
end

local function render_cursor(payload)
  local model = (payload.model and payload.model.display_name) or "?"
  local param = payload.model and payload.model.param_summary or nil
  local max_mode = payload.model and payload.model.max_mode == true
  local cwd = payload.cwd or (payload.workspace and payload.workspace.current_dir) or ""
  local transcript = payload.transcript_path or ""
  local cw = payload.context_window or {}
  local ctx = floor_pct(cw.used_percentage)
  local worktree = payload.worktree and payload.worktree.name or nil
  local vim_mode = payload.vim and payload.vim.mode or nil
  local effort = effort_level(payload)

  local model_extra = ""
  if cfg.show_effort then
    if effort then
      model_extra = effort_segment(effort)
    else
      if type(param) == "string" and param ~= "" then
        model_extra = model_extra .. string.format(" %s%s%s", DIM, param, RST)
      end
      if max_mode then
        model_extra = model_extra .. string.format(" %smax%s", MAGENTA, RST)
      end
    end
  end

  local extra = git_segment(cwd)
  if type(worktree) == "string" and worktree ~= "" then
    extra = extra .. string.format("  %s·%s  %swt:%s%s%s", DIM, RST, MAGENTA, CYAN, worktree, RST)
  end
  if type(vim_mode) == "string" and vim_mode ~= "" then
    extra = extra .. string.format("  %s·%s  %s%s%s", DIM, RST, DIM, vim_mode, RST)
  end

  local line1 = string.format(
    "%s◆%s %s%s%s%s  %s·%s  %s%s%s%s",
    BOLD .. CYAN, RST,
    BOLD .. CYAN, model, RST, model_extra,
    DIM, RST,
    YELLOW, project_name(cwd), RST,
    extra
  )

  local parts = {}
  if ctx then parts[#parts + 1] = print_context_segment(ctx) end
  local cache = prompt_cache_segment(transcript)
  if cache ~= "" then parts[#parts + 1] = cache end
  local line2 = join_parts(parts)
  if line2 == "" then line2 = DIM .. t("waiting") .. RST end
  return line1 .. "\n" .. line2
end

local mode = arg[1] or "claude"
load_config()
local raw = read_stdin()
local payload = json.decode(raw)
if type(payload) ~= "table" then
  io.write(DIM .. t("waiting") .. RST .. "\n")
  os.exit(0)
end

if mode == "cursor" then
  io.write(render_cursor(payload) .. "\n")
else
  io.write(render_claude(payload) .. "\n")
end
