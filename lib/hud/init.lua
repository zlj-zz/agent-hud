-- agent-hud library package.
-- CLI: require("hud").main("claude"|"cursor") with JSON on stdin.

local json = require("hud.dkjson")
local ansi = require("hud.ansi")
local config = require("hud.config")
local i18n = require("hud.i18n")
local util = require("hud.util")
local render = require("hud.render")

local M = {}

local function detect_root()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    local dir = src:sub(2):match("(.*/)") or "./"
    -- lib/hud/init.lua -> repo root
    dir = dir:gsub("/lib/hud/$", "/")
    return (dir:gsub("/$", ""))
  end
  return "."
end

function M.main(mode)
  mode = mode or "claude"
  local root = detect_root()
  package.path = table.concat({
    root .. "/lib/?.lua",
    root .. "/lib/?/init.lua",
    package.path,
  }, ";")

  -- Re-require is fine; modules are cached after path is set on first load.
  -- Ensure config sees the correct root even when required early.
  config.load(root)

  local raw = util.read_stdin()
  local payload = json.decode(raw)
  if type(payload) ~= "table" then
    io.write(ansi.DIM .. i18n.t("waiting") .. ansi.RST .. "\n")
    return 0
  end

  if mode == "cursor" then
    io.write(render.cursor(payload) .. "\n")
  else
    io.write(render.claude(payload) .. "\n")
  end
  return 0
end

return M
