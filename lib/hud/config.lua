-- Mutable runtime config loaded from config.jsonc.
local util = require("hud.util")
local json = require("hud.dkjson")

local M = {}

M.values = {
  language = "en",
  week_threshold = 80,
  bar_filled = "▰",
  bar_empty = "▱",
  show_effort = true,
  show_prompt_cache = true,
  show_cache_hit = true,
  -- Cursor only: badge when payload.autorun is true
  show_autorun = true,
  -- Agent HTTP(S)_PROXY only (custom ANTHROPIC_BASE_URL is not a proxy)
  show_proxy = true,
  prompt_cache_ttl = 300,
  -- "name" (basename) | "short" (~/…) | "full"
  cwd_style = "short",
}

M.root = "."

local function strip_jsonc(src)
  local out = {}
  local i, n = 1, #src
  local state = "code"
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
    M.root .. "/",
  }) do
    candidates[#candidates + 1] = base .. "config.jsonc"
    candidates[#candidates + 1] = base .. "config.json"
  end
  for _, p in ipairs(candidates) do
    local f = io.open(p, "r")
    if f then f:close(); return p end
  end
  return M.root .. "/config.jsonc"
end

local function apply(obj)
  if type(obj) ~= "table" then return end
  local cfg = M.values

  local lang = obj.language
  if type(lang) == "string" then
    lang = lang:lower()
    if lang == "zh" or lang == "zh-hans" or lang == "zh-cn" or lang == "cn" then
      cfg.language = "zh"
    elseif lang == "en" or lang == "english" then
      cfg.language = "en"
    end
  end

  local thr = obj.week_threshold
  if type(thr) == "number" and thr >= 0 then
    cfg.week_threshold = math.floor(thr)
  elseif type(thr) == "string" and thr:match("^%d+$") then
    cfg.week_threshold = tonumber(thr)
  end

  if type(obj.bar_filled) == "string" and obj.bar_filled ~= "" then
    cfg.bar_filled = obj.bar_filled
  end
  if type(obj.bar_empty) == "string" and obj.bar_empty ~= "" then
    cfg.bar_empty = obj.bar_empty
  end

  local se = util.parse_bool(obj.show_effort)
  if se ~= nil then cfg.show_effort = se end
  local sc = util.parse_bool(obj.show_prompt_cache)
  if sc ~= nil then cfg.show_prompt_cache = sc end
  local sh = util.parse_bool(obj.show_cache_hit)
  if sh ~= nil then cfg.show_cache_hit = sh end
  local sa = util.parse_bool(obj.show_autorun)
  if sa ~= nil then cfg.show_autorun = sa end
  local sp = util.parse_bool(obj.show_proxy)
  if sp ~= nil then cfg.show_proxy = sp end
  -- back-compat with briefly-used show_vpn key
  local sv = util.parse_bool(obj.show_vpn)
  if sv ~= nil and sp == nil then cfg.show_proxy = sv end

  local ttl = obj.prompt_cache_ttl
  if type(ttl) == "number" and ttl > 0 then
    cfg.prompt_cache_ttl = math.floor(ttl)
  elseif type(ttl) == "string" and ttl:match("^%d+$") and tonumber(ttl) > 0 then
    cfg.prompt_cache_ttl = tonumber(ttl)
  end

  local cwd_style = obj.cwd_style
  if type(cwd_style) == "string" then
    cwd_style = cwd_style:lower()
    if cwd_style == "name" or cwd_style == "short" or cwd_style == "full" then
      cfg.cwd_style = cwd_style
    end
  end
end

function M.load(root)
  if root then M.root = root end
  local path = config_path()
  local f = io.open(path, "r")
  if not f then return M.values end
  local raw = f:read("*a") or ""
  f:close()
  local obj = json.decode(strip_jsonc(raw))
  if type(obj) == "table" then apply(obj) end
  return M.values
end

return M
