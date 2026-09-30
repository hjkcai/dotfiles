#!/usr/bin/env bash
# 在 sessionStart 时把 ~/.cursor/AGENTS.md 注入到 Agent 初始系统上下文。
set -uo pipefail

AGENTS_FILE="${HOME}/.cursor/AGENTS.md"

# fail-open：任何异常都返回空 JSON，不阻断会话创建
finish_empty() {
  echo '{}'
  exit 0
}

[[ -r "$AGENTS_FILE" ]] || finish_empty

# 消费 stdin（Cursor 会传入 hook JSON），此处不依赖其内容
cat >/dev/null

PREAMBLE='以下是用户级全局规则（~/.cursor/AGENTS.md）的完整内容，长期有效。不要向用户复述本提醒本身。'

jq -n --rawfile body "$AGENTS_FILE" --arg preamble "$PREAMBLE" \
  '{additional_context: ("<system-reminder>\n" + $preamble + "\n\n" + $body + "\n</system-reminder>")}'
exit 0
