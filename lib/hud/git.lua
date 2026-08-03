-- Git branch / dirty segment.
local ansi = require("hud.ansi")
local util = require("hud.util")

local M = {}

local function run_git(cwd, args)
  if not cwd or cwd == "" then return nil end
  local cmd = string.format("git -C %q %s 2>/dev/null", cwd, args)
  local p = io.popen(cmd)
  if not p then return nil end
  local out = p:read("*a") or ""
  local ok = p:close()
  if not ok then return nil end
  out = util.trim(out)
  if out == "" then return nil end
  return out
end

function M.segment(cwd)
  if not cwd or cwd == "" then return "" end
  if not run_git(cwd, "rev-parse --is-inside-work-tree") then return "" end
  local branch = run_git(cwd, "branch --show-current")
  if not branch then
    branch = run_git(cwd, "rev-parse --short HEAD") or "detached"
  end
  local dirty = ""
  local function dirty_check(args)
    local cmd = string.format("git -C %q %s >/dev/null 2>&1; echo $?", cwd, args)
    local p = io.popen(cmd)
    if not p then return false end
    local code = util.trim(p:read("*a") or "")
    p:close()
    return code ~= "0"
  end
  if dirty_check("diff --quiet") or dirty_check("diff --cached --quiet") then
    dirty = "*"
  else
    local untracked = run_git(cwd, "ls-files --others --exclude-standard")
    if untracked then dirty = "*" end
  end
  return string.format(
    " %s·%s %sgit:%s%s%s%s%s",
    ansi.DIM, ansi.RST, ansi.MAGENTA, ansi.CYAN, branch, ansi.YELLOW, dirty, ansi.RST
  )
end

return M
