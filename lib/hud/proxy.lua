-- Whether *this agent process* uses an HTTP(S) proxy env.
-- Does NOT treat custom ANTHROPIC_BASE_URL (API gateways) as proxy.
-- Does NOT inspect macOS system VPN / system proxy.
local ansi = require("hud.ansi")
local config = require("hud.config")
local json = require("hud.dkjson")
local util = require("hud.util")

local M = {}

local PROXY_KEYS = {
  "HTTPS_PROXY", "https_proxy",
  "HTTP_PROXY", "http_proxy",
  "ALL_PROXY", "all_proxy",
}

local function first_nonempty(map, keys)
  if type(map) ~= "table" then return nil end
  for _, k in ipairs(keys) do
    local v = map[k]
    if type(v) == "string" then
      v = util.trim(v)
      if v ~= "" then return v end
    end
  end
  return nil
end

local function env_proxy()
  local map = {}
  for _, k in ipairs(PROXY_KEYS) do
    local v = os.getenv(k)
    if v and v ~= "" then map[k] = v end
  end
  return first_nonempty(map, PROXY_KEYS)
end

local function claude_settings_proxy()
  local home = os.getenv("HOME")
  if not home or home == "" then return nil end
  local path = home:gsub("/$", "") .. "/.claude/settings.json"
  local f = io.open(path, "r")
  if not f then return nil end
  local raw = f:read("*a") or ""
  f:close()
  local obj = json.decode(raw)
  if type(obj) ~= "table" or type(obj.env) ~= "table" then return nil end
  return first_nonempty(obj.env, PROXY_KEYS)
end

function M.segment(mode)
  if not config.values.show_proxy then return "" end
  mode = mode or "claude"

  local url = env_proxy()
  if not url and mode == "claude" then
    url = claude_settings_proxy()
  end
  if not url then return "" end

  return string.format(
    " %s·%s %s⇄%s",
    ansi.DIM, ansi.RST,
    ansi.PROXY_BLUE, ansi.RST
  )
end

return M
