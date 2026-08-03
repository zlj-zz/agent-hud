-- Line rendering for Claude Code / Cursor CLI payloads.
local ansi = require("hud.ansi")
local config = require("hud.config")
local i18n = require("hud.i18n")
local util = require("hud.util")
local git = require("hud.git")
local effort = require("hud.effort")
local cache = require("hud.cache")

local M = {}

local function bar(pct, width)
  width = width or 10
  pct = pct or 0
  local filled = math.floor((pct * width + 50) / 100)
  if filled > width then filled = width end
  if filled < 0 then filled = 0 end
  local cfg = config.values
  return string.rep(cfg.bar_filled, filled) .. string.rep(cfg.bar_empty, width - filled)
end

local function context_color(pct)
  if pct >= 85 then return ansi.RED end
  if pct >= 70 then return ansi.YELLOW end
  return ansi.GREEN
end

local function usage_color(pct)
  if pct >= 90 then return ansi.RED end
  if pct >= 75 then return ansi.BRIGHT_MAGENTA end
  return ansi.BRIGHT_BLUE
end

local function context_segment(pct)
  local cc = context_color(pct)
  return string.format(
    "%s%s%s %s%s%s %s%d%%%s",
    ansi.DIM, i18n.t("context"), ansi.RST,
    cc, bar(pct), ansi.RST,
    cc .. ansi.BOLD, pct, ansi.RST
  )
end

local function join_parts(parts)
  local out = {}
  for _, p in ipairs(parts) do
    if p and p ~= "" then out[#out + 1] = p end
  end
  return table.concat(out, "  " .. ansi.DIM .. "│" .. ansi.RST .. "  ")
end

function M.claude(payload)
  local model = (payload.model and payload.model.display_name) or "?"
  local cwd = payload.cwd or (payload.workspace and payload.workspace.current_dir) or ""
  local transcript = payload.transcript_path or ""
  local cw = payload.context_window or {}
  local ctx = util.floor_pct(cw.used_percentage)
  local rl = payload.rate_limits or {}
  local five = rl.five_hour or {}
  local seven = rl.seven_day or {}
  local usage = util.floor_pct(five.used_percentage)
  local week = util.floor_pct(seven.used_percentage)

  local line1 = string.format(
    "%s◆%s %s%s%s%s  %s·%s  %s%s%s%s",
    ansi.BOLD .. ansi.CYAN, ansi.RST,
    ansi.BOLD .. ansi.CYAN, model, ansi.RST, effort.segment(effort.level(payload)),
    ansi.DIM, ansi.RST,
    ansi.YELLOW, util.display_cwd(cwd, config.values.cwd_style), ansi.RST,
    git.segment(cwd)
  )

  local parts = {}
  if ctx then parts[#parts + 1] = context_segment(ctx) end
  if usage then
    local uc = usage_color(usage)
    local seg = string.format(
      "%s%s%s %s%s%s %s%d%%%s",
      ansi.DIM, i18n.t("usage"), ansi.RST,
      uc, bar(usage), ansi.RST,
      uc .. ansi.BOLD, usage, ansi.RST
    )
    local reset = util.rel_time(five.resets_at)
    if reset then
      seg = seg .. string.format(" %s· %s%s", ansi.DIM, reset, ansi.RST)
    end
    parts[#parts + 1] = seg
  end
  if week and week >= config.values.week_threshold then
    local wc = usage_color(week)
    parts[#parts + 1] = string.format(
      "%s%s%s %s%s%s %s%d%%%s",
      ansi.DIM, i18n.t("week"), ansi.RST,
      wc, bar(week), ansi.RST,
      wc .. ansi.BOLD, week, ansi.RST
    )
  end
  local cache_seg = cache.segment(transcript)
  if cache_seg ~= "" then parts[#parts + 1] = cache_seg end

  local line2 = join_parts(parts)
  if line2 == "" then line2 = ansi.DIM .. i18n.t("waiting") .. ansi.RST end
  return line1 .. "\n" .. line2
end

function M.cursor(payload)
  local model = (payload.model and payload.model.display_name) or "?"
  local param = payload.model and payload.model.param_summary or nil
  local max_mode = payload.model and payload.model.max_mode == true
  local cwd = payload.cwd or (payload.workspace and payload.workspace.current_dir) or ""
  local transcript = payload.transcript_path or ""
  local cw = payload.context_window or {}
  local ctx = util.floor_pct(cw.used_percentage)
  local worktree = payload.worktree and payload.worktree.name or nil
  local vim_mode = payload.vim and payload.vim.mode or nil
  local level = effort.level(payload)

  local model_extra = ""
  if config.values.show_effort then
    if level then
      model_extra = effort.segment(level)
    else
      if type(param) == "string" and param ~= "" then
        model_extra = model_extra .. string.format(" %s%s%s", ansi.DIM, param, ansi.RST)
      end
      if max_mode then
        model_extra = model_extra .. string.format(" %smax%s", ansi.MAGENTA, ansi.RST)
      end
    end
  end

  local extra = git.segment(cwd)
  if type(worktree) == "string" and worktree ~= "" then
    extra = extra .. string.format(
      "  %s·%s  %swt:%s%s%s",
      ansi.DIM, ansi.RST, ansi.MAGENTA, ansi.CYAN, worktree, ansi.RST
    )
  end
  if type(vim_mode) == "string" and vim_mode ~= "" then
    extra = extra .. string.format("  %s·%s  %s%s%s", ansi.DIM, ansi.RST, ansi.DIM, vim_mode, ansi.RST)
  end

  local line1 = string.format(
    "%s◆%s %s%s%s%s  %s·%s  %s%s%s%s",
    ansi.BOLD .. ansi.CYAN, ansi.RST,
    ansi.BOLD .. ansi.CYAN, model, ansi.RST, model_extra,
    ansi.DIM, ansi.RST,
    ansi.YELLOW, util.display_cwd(cwd, config.values.cwd_style), ansi.RST,
    extra
  )

  local parts = {}
  if ctx then parts[#parts + 1] = context_segment(ctx) end
  local cache_seg = cache.segment(transcript)
  if cache_seg ~= "" then parts[#parts + 1] = cache_seg end
  local line2 = join_parts(parts)
  if line2 == "" then line2 = ansi.DIM .. i18n.t("waiting") .. ansi.RST end
  return line1 .. "\n" .. line2
end

return M
