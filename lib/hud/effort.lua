-- Effort level parsing / rendering.
local ansi = require("hud.ansi")
local config = require("hud.config")

local M = {}

local function symbol(level)
  level = tostring(level or ""):lower()
  if level == "low" then return "○" end
  if level == "medium" or level == "med" then return "◔" end
  if level == "high" then return "◑" end
  if level == "xhigh" then return "◕" end
  if level == "max" then return "●" end
  return "◉"
end

function M.level(payload)
  local e = payload.effort
  if type(e) == "string" and e ~= "" then return e end
  if type(e) == "table" and type(e.level) == "string" and e.level ~= "" then
    return e.level
  end
  return nil
end

function M.segment(level)
  if not config.values.show_effort or not level then return "" end
  return string.format(
    " %s%s%s %s%s%s",
    ansi.MAGENTA, symbol(level), ansi.RST, ansi.DIM, level, ansi.RST
  )
end

return M
