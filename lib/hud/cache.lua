-- Prompt-cache TTL countdown + last-turn cache-hit estimate.
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

local function token(n)
  if type(n) ~= "number" or n ~= n or n < 0 then return 0 end
  return math.floor(n)
end

local function format_k(n)
  if n >= 1000000 then
    return string.format("%.1fM", n / 1000000)
  end
  if n >= 1000 then
    local k = n / 1000
    if k >= 100 or k == math.floor(k) then
      return string.format("%dk", math.floor(k + 0.5))
    end
    return string.format("%.1fk", k)
  end
  return tostring(n)
end

local function hit_color(pct)
  if pct >= 70 then return ansi.GREEN end
  if pct >= 30 then return ansi.YELLOW end
  return ansi.DIM
end

-- TTL countdown from transcript (Claude-oriented; Cursor often lacks path/format).
function M.ttl_segment(transcript)
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

-- Last-turn cache hit from context_window.current_usage.
-- mode: "claude" | "cursor" — Cursor adds read tokens when useful (no usage line).
function M.hit_segment(payload, mode)
  if not config.values.show_cache_hit then return "" end
  local cw = payload and payload.context_window
  local u = cw and cw.current_usage
  if type(u) ~= "table" then return "" end

  local has_cache_field = type(u.cache_read_input_tokens) == "number"
    or type(u.cache_creation_input_tokens) == "number"
  if not has_cache_field then return "" end

  local input = token(u.input_tokens)
  local create = token(u.cache_creation_input_tokens)
  local read = token(u.cache_read_input_tokens)
  local total = input + create + read
  if total <= 0 then return "" end

  local pct = math.floor((read * 100 / total) + 0.5)
  if pct > 100 then pct = 100 end
  local color = hit_color(pct)

  -- Claude: compact percent (TTL segment covers "time left").
  if mode ~= "cursor" then
    return string.format(
      "%s%s%s %s%d%%%s",
      ansi.DIM, i18n.t("hit"), ansi.RST,
      color .. ansi.BOLD, pct, ansi.RST
    )
  end

  -- Cursor: percent + cached-read size when non-zero (often the only cache signal).
  if read > 0 then
    return string.format(
      "%s%s%s %s%d%%%s %s· %s%s",
      ansi.DIM, i18n.t("hit"), ansi.RST,
      color .. ansi.BOLD, pct, ansi.RST,
      ansi.DIM, format_k(read), ansi.RST
    )
  end
  if create > 0 then
    return string.format(
      "%s%s%s %s%d%%%s %s· +%s%s",
      ansi.DIM, i18n.t("hit"), ansi.RST,
      color .. ansi.BOLD, pct, ansi.RST,
      ansi.DIM, format_k(create), ansi.RST
    )
  end
  return string.format(
    "%s%s%s %s%d%%%s",
    ansi.DIM, i18n.t("hit"), ansi.RST,
    color .. ansi.BOLD, pct, ansi.RST
  )
end

-- Back-compat alias
function M.segment(transcript)
  return M.ttl_segment(transcript)
end

return M
