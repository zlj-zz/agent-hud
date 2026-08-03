-- Prompt-cache countdown from transcript tail scan.
local json = require("hud.dkjson")
local ansi = require("hud.ansi")
local config = require("hud.config")
local i18n = require("hud.i18n")

local M = {}

local function parse_iso_to_epoch(ts)
  if type(ts) ~= "string" or ts == "" then return nil end
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
    if line:find('"type":"assistant"', 1, true) or line:find('"type"%s*:%s*"assistant"', 1) then
      local obj = json.decode(line)
      if type(obj) == "table" and obj.type == "assistant" and type(obj.timestamp) == "string" then
        last_ts = obj.timestamp
      end
    end
  end
  if not last_ts then return nil end
  return parse_iso_to_epoch(last_ts)
end

local function format_countdown(remaining)
  if remaining <= 0 then return i18n.t("expired") end
  local hours = math.floor(remaining / 3600)
  local mins = math.floor((remaining % 3600) / 60)
  local secs = remaining % 60
  if hours > 0 then
    return string.format("%dh %dm %ds", hours, mins, secs)
  end
  return string.format("%dm %ds", mins, secs)
end

function M.segment(transcript)
  if not config.values.show_prompt_cache then return "" end
  local epoch = last_assistant_epoch(transcript)
  if not epoch then return "" end
  local ttl = config.values.prompt_cache_ttl
  local remaining = epoch + ttl - os.time()
  local warn = math.floor(ttl / 5)
  if warn < 60 then warn = 60 end
  if warn > ttl then warn = ttl end
  local color = ansi.GREEN
  if remaining <= 0 then
    color = ansi.DIM
  elseif remaining <= warn then
    color = ansi.YELLOW
  end
  return string.format(
    "%s%s%s %s⏱ %s%s",
    ansi.DIM, i18n.t("cache"), ansi.RST, color, format_countdown(remaining), ansi.RST
  )
end

return M
