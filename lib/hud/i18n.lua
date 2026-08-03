-- Bilingual labels.
local config = require("hud.config")

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

local M = {}

function M.t(key)
  local pack = labels[config.values.language] or labels.en
  return pack[key] or key
end

return M
