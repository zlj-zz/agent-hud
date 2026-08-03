-- Small shared helpers.
local M = {}

function M.trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.parse_bool(v)
  if type(v) == "boolean" then return v end
  if type(v) == "number" then return v ~= 0 end
  if type(v) ~= "string" then return nil end
  local s = v:lower()
  if s == "true" or s == "1" or s == "yes" or s == "on" then return true end
  if s == "false" or s == "0" or s == "no" or s == "off" then return false end
  return nil
end

function M.floor_pct(v)
  if type(v) ~= "number" then return nil end
  if v ~= v then return nil end
  local n = math.floor(v)
  if n < 0 then n = 0 end
  if n > 100 then n = 100 end
  return n
end

function M.rel_time(ts)
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

function M.project_name(cwd)
  if not cwd or cwd == "" then return "?" end
  return cwd:match("([^/]+)$") or cwd
end

function M.read_stdin()
  local chunks = {}
  while true do
    local chunk = io.read(4096)
    if not chunk then break end
    chunks[#chunks + 1] = chunk
  end
  return table.concat(chunks)
end

function M.script_root()
  local src = debug.getinfo(2, "S").source
  -- Prefer the caller's file if available; fall back to this module.
  if not src or src:sub(1, 1) ~= "@" then
    src = debug.getinfo(1, "S").source
  end
  if src:sub(1, 1) == "@" then
    local dir = src:sub(2):match("(.*/)") or "./"
    dir = dir:gsub("/lib/hud/$", "/"):gsub("/lib/$", "/")
    return (dir:gsub("/$", ""))
  end
  return "."
end

return M
