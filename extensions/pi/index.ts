/**
 * agent-hud — pi Extension
 *
 * Dual-line statusline for pi coding agent.
 * Renders model + cwd + git + proxy on line 1, context usage bar on line 2.
 *
 * Reads config from $AGENT_HUD_CONFIG → ~/.config/agent-hud/config.jsonc → defaults.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, basename } from "node:path";

// ─── Config ────────────────────────────────────────────────────────────────

interface HudConfig {
  language: "en" | "zh";
  cwd_style: "name" | "short" | "full";
  bar_filled: string;
  bar_empty: string;
  show_effort: boolean;
  show_proxy: boolean;
  week_threshold: number;
}

const DEFAULTS: HudConfig = {
  language: "en",
  cwd_style: "short",
  bar_filled: "▰",
  bar_empty: "▱",
  show_effort: true,
  show_proxy: true,
  week_threshold: 80,
};

const LABELS: Record<string, Record<string, string>> = {
  en: { context: "Context", waiting: "Waiting for session data…" },
  zh: { context: "上下文", waiting: "等待会话数据…" },
};

function t(key: string, lang: string): string {
  const pack = LABELS[lang] ?? LABELS["en"]!;
  return pack[key] ?? key;
}

// ─── Config loading ────────────────────────────────────────────────────────

function stripJsonc(src: string): string {
  const out: string[] = [];
  let i = 0;
  let state: "code" | "string" | "line" | "block" | "escape" = "code";

  while (i < src.length) {
    const c = src[i]!;
    const n1 = src[i + 1] ?? "";

    if (state === "code") {
      if (c === '"') {
        state = "string";
        out.push(c);
        i++;
      } else if (c === "/" && n1 === "/") {
        state = "line";
        i += 2;
      } else if (c === "/" && n1 === "*") {
        state = "block";
        i += 2;
      } else {
        out.push(c);
        i++;
      }
    } else if (state === "line") {
      if (c === "\n") {
        state = "code";
        out.push(c);
      }
      i++;
    } else if (state === "block") {
      if (c === "*" && n1 === "/") {
        state = "code";
        i += 2;
      } else {
        if (c === "\n") out.push(c);
        i++;
      }
    } else if (state === "string") {
      out.push(c);
      if (c === "\\") state = "escape";
      else if (c === '"') state = "code";
      i++;
    } else if (state === "escape") {
      out.push(c);
      state = "string";
      i++;
    }
  }
  return out.join("");
}

function findConfigPath(): string | null {
  const env = process.env["AGENT_HUD_CONFIG"];
  if (env && env.trim() !== "") return env;

  const home = homedir();
  const xdg = process.env["XDG_CONFIG_HOME"];
  const candidates: string[] = [];

  if (xdg && xdg.trim() !== "") {
    const base = xdg.replace(/\/$/, "") + "/agent-hud/";
    candidates.push(base + "config.jsonc", base + "config.json");
  }
  candidates.push(
    home + "/.config/agent-hud/config.jsonc",
    home + "/.config/agent-hud/config.json",
    home + "/.agent-hud/config.jsonc",
    home + "/.agent-hud/config.json",
  );

  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

function loadConfig(): HudConfig {
  const path = findConfigPath();
  if (!path) return { ...DEFAULTS };

  try {
    const raw = readFileSync(path, "utf-8");
    const obj = JSON.parse(stripJsonc(raw));
    if (typeof obj !== "object" || obj === null) return { ...DEFAULTS };

    const cfg = { ...DEFAULTS };

    if (typeof obj.language === "string") {
      const lang = obj.language.toLowerCase();
      if (lang === "zh" || lang === "zh-hans" || lang === "zh-cn" || lang === "cn") {
        cfg.language = "zh";
      } else if (lang === "en" || lang === "english") {
        cfg.language = "en";
      }
    }

    if (typeof obj.cwd_style === "string") {
      const s = obj.cwd_style.toLowerCase();
      if (s === "name" || s === "short" || s === "full") cfg.cwd_style = s;
    }

    if (typeof obj.bar_filled === "string" && obj.bar_filled !== "") {
      cfg.bar_filled = obj.bar_filled;
    }
    if (typeof obj.bar_empty === "string" && obj.bar_empty !== "") {
      cfg.bar_empty = obj.bar_empty;
    }

    if (typeof obj.show_effort === "boolean") cfg.show_effort = obj.show_effort;
    if (typeof obj.show_proxy === "boolean") cfg.show_proxy = obj.show_proxy;
    // back-compat with show_vpn
    if (typeof obj.show_vpn === "boolean") cfg.show_proxy = obj.show_vpn;

    if (typeof obj.week_threshold === "number") {
      cfg.week_threshold = Math.floor(obj.week_threshold);
    } else if (typeof obj.week_threshold === "string" && /^\d+$/.test(obj.week_threshold)) {
      cfg.week_threshold = parseInt(obj.week_threshold, 10);
    }

    return cfg;
  } catch {
    return { ...DEFAULTS };
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

function floorPct(v: number | undefined | null): number | null {
  if (typeof v !== "number" || isNaN(v)) return null;
  const n = Math.floor(v);
  return Math.max(0, Math.min(100, n));
}

function displayCwd(cwd: string, style: string): string {
  if (!cwd) return "?";
  if (style === "name") return basename(cwd) || cwd;
  if (style === "full") return cwd;
  // short
  const home = homedir();
  if (home && cwd.startsWith(home + "/")) return "~/" + cwd.slice(home.length + 1);
  if (home && cwd === home) return "~";
  return cwd;
}

function bar(pct: number | null, width: number, filled: string, empty: string): string {
  if (pct === null) return "";
  const n = Math.floor((pct * width + 50) / 100);
  const clamped = Math.max(0, Math.min(width, n));
  return filled.repeat(clamped) + empty.repeat(width - clamped);
}

function contextColor(pct: number): string {
  if (pct >= 85) return "\x1b[31m"; // red
  if (pct >= 70) return "\x1b[33m"; // yellow
  return "\x1b[32m"; // green
}

// ─── Git ───────────────────────────────────────────────────────────────────

let gitCache: { branch: string; dirty: boolean } | null = null;
let gitCacheCwd: string | null = null;
let gitCacheTime = 0;
const GIT_CACHE_TTL = 3000; // 3 seconds

function runGit(cwd: string, args: string): string | null {
  try {
    const out = execSync(`git -C "${cwd}" ${args} 2>/dev/null`, {
      encoding: "utf-8",
      timeout: 2000,
      cwd,
    });
    const trimmed = out.trim();
    return trimmed || null;
  } catch {
    return null;
  }
}

function getGitSegment(cwd: string): string {
  const now = Date.now();
  if (gitCacheCwd === cwd && gitCache && now - gitCacheTime < GIT_CACHE_TTL) {
    return formatGit(gitCache.branch, gitCache.dirty);
  }

  if (!cwd) {
    gitCache = null;
    gitCacheCwd = null;
    return "";
  }

  const inside = runGit(cwd, "rev-parse --is-inside-work-tree");
  if (!inside) {
    gitCache = null;
    gitCacheCwd = null;
    return "";
  }

  let branch = runGit(cwd, "branch --show-current");
  if (!branch) {
    branch = runGit(cwd, "rev-parse --short HEAD") ?? "detached";
  }

  let dirty = false;
  try {
    execSync(`git -C "${cwd}" diff --quiet 2>/dev/null`, { timeout: 2000, cwd });
    execSync(`git -C "${cwd}" diff --cached --quiet 2>/dev/null`, { timeout: 2000, cwd });
  } catch {
    dirty = true;
  }
  if (!dirty) {
    const untracked = runGit(cwd, "ls-files --others --exclude-standard");
    if (untracked) dirty = true;
  }

  gitCache = { branch, dirty };
  gitCacheCwd = cwd;
  gitCacheTime = now;
  return formatGit(branch, dirty);
}

function formatGit(branch: string, dirty: boolean): string {
  const dim = "\x1b[2m";
  const rst = "\x1b[0m";
  const magenta = "\x1b[35m";
  const cyan = "\x1b[36m";
  const yellow = "\x1b[33m";
  const star = dirty ? yellow + "*" : "";
  return ` ${dim}·${rst} ${magenta}git:${cyan}${branch}${star}${rst}`;
}

// ─── Proxy ─────────────────────────────────────────────────────────────────

const PROXY_KEYS = ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy", "ALL_PROXY", "all_proxy"];

function getProxySegment(show: boolean): string {
  if (!show) return "";
  for (const key of PROXY_KEYS) {
    const val = process.env[key];
    if (val && val.trim() !== "") {
      const dim = "\x1b[2m";
      const rst = "\x1b[0m";
      const blue = "\x1b[38;2;108;182;255m";
      return ` ${dim}·${rst} ${blue}⇄${rst}`;
    }
  }
  return "";
}

// ─── Thinking level ────────────────────────────────────────────────────────

function effortSymbol(level: string | undefined): string {
  if (!level) return "";
  switch (level.toLowerCase()) {
    case "low": return "○";
    case "medium": case "med": return "◔";
    case "high": return "◑";
    case "xhigh": return "◕";
    case "max": return "●";
    default: return "◉";
  }
}

function getEffortSegment(level: string | undefined, show: boolean): string {
  if (!show || !level || level === "off") return "";
  const magenta = "\x1b[35m";
  const dim = "\x1b[2m";
  const rst = "\x1b[0m";
  return ` ${magenta}${effortSymbol(level)}${rst} ${dim}${level}${rst}`;
}

// ─── Render ────────────────────────────────────────────────────────────────

function renderLines(
  cfg: HudConfig,
  modelName: string,
  cwd: string,
  thinkingLevel: string | undefined,
  contextPct: number | null,
): [string, string] {
  const bold = "\x1b[1m";
  const cyan = "\x1b[36m";
  const yellow = "\x1b[33m";
  const dim = "\x1b[2m";
  const rst = "\x1b[0m";

  // Line 1: ◆ model [effort] · cwd [git] [proxy]
  const effort = getEffortSegment(thinkingLevel, cfg.show_effort);
  const git = getGitSegment(cwd);
  const proxy = getProxySegment(cfg.show_proxy);
  const line1 =
    `${bold}${cyan}◆${rst} ${bold}${cyan}${modelName}${rst}${effort}` +
    ` ${dim}·${rst} ${yellow}${displayCwd(cwd, cfg.cwd_style)}${rst}${git}${proxy}`;

  // Line 2: Context ▰▰▰▱▱ 42%
  let line2 = "";
  if (contextPct !== null) {
    const cc = contextColor(contextPct);
    const b = bar(contextPct, 10, cfg.bar_filled, cfg.bar_empty);
    line2 = `${dim}${t("context", cfg.language)}${rst} ${cc}${b}${rst} ${cc}${bold}${contextPct}%${rst}`;
  } else {
    line2 = dim + t("waiting", cfg.language) + rst;
  }

  return [line1, line2];
}

// ─── Extension ─────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  const cfg = loadConfig();
  let currentModelName = "?";
  let currentThinkingLevel: string | undefined;
  let contextPct: number | null = null;

  function refresh(ctx: { cwd: string; ui: { setWidget: (k: string, v: any, o?: any) => void } }) {
    const [line1, line2] = renderLines(cfg, currentModelName, ctx.cwd, currentThinkingLevel, contextPct);
    ctx.ui.setWidget(
      "agent-hud",
      [line1, line2],
      { placement: "belowEditor" },
    );
  }

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.model) {
      currentModelName = ctx.model.displayName ?? ctx.model.id ?? "?";
      currentThinkingLevel = ctx.thinkingLevel;
    }
    refresh({ cwd: ctx.cwd, ui: ctx.ui });
  });

  pi.on("model_select", async (event, ctx) => {
    currentModelName = event.model.displayName ?? event.model.id ?? "?";
    currentThinkingLevel = ctx.thinkingLevel;
    refresh({ cwd: ctx.cwd, ui: ctx.ui });
  });

  pi.on("thinking_level_select", async (event, ctx) => {
    currentThinkingLevel = event.level;
    refresh({ cwd: ctx.cwd, ui: ctx.ui });
  });

  pi.on("turn_end", async (_event, ctx) => {
    const usage = ctx.getContextUsage();
    contextPct = floorPct(usage?.percent);
    currentThinkingLevel = ctx.thinkingLevel;
    if (ctx.model) {
      currentModelName = ctx.model.displayName ?? ctx.model.id ?? "?";
    }
    refresh({ cwd: ctx.cwd, ui: ctx.ui });
  });

  pi.on("agent_settled", async (_event, ctx) => {
    const usage = ctx.getContextUsage();
    contextPct = floorPct(usage?.percent);
    refresh({ cwd: ctx.cwd, ui: ctx.ui });
  });

  // Also refresh context on tool_execution_end to get live usage updates
  pi.on("tool_execution_end", async (_event, ctx) => {
    const usage = ctx.getContextUsage();
    contextPct = floorPct(usage?.percent);
    refresh({ cwd: ctx.cwd, ui: ctx.ui });
  });
}
