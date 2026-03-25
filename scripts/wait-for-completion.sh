#!/usr/bin/env bash
# wait-for-completion.sh
# 监听 codex-subagent pane 的输出，检测 Codex 任务完成
#
# 用法:
#   ./scripts/wait-for-completion.sh
#   ./scripts/wait-for-completion.sh --timeout 300   # 最多等 5 分钟

set -euo pipefail

# ── 参数解析 ─────────────────────────────────────────────────────────────────
TIMEOUT=180   # 默认超时 3 分钟
POLL=2        # 轮询间隔（秒）

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout|-t) TIMEOUT="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

# ── 环境检查 ─────────────────────────────────────────────────────────────────
if [[ -z "${TMUX:-}" ]]; then
  echo "错误: 需要在 tmux 会话中运行" >&2
  exit 1
fi

# ── 找到 codex-subagent pane ───────────────────────────────────────────────────
WORKER_PANE=$(tmux list-panes -F '#{pane_id}:#{pane_title}' 2>/dev/null \
  | grep ':codex-subagent$' \
  | head -1 \
  | cut -d: -f1 || true)

if [[ -z "$WORKER_PANE" ]]; then
  echo "错误: 未找到 codex-subagent pane。请先运行 codex-dispatch.sh" >&2
  exit 1
fi

echo "正在等待 Codex 完成任务..."
echo "  Pane: $WORKER_PANE  超时: ${TIMEOUT}s"
echo "  按 Ctrl+C 取消等待"
echo ""

# ── 完成标志检测 ─────────────────────────────────────────────────────────────
# Codex 完成后会回到 shell prompt，特征是最后一行出现 $ 或 > 提示符
# 同时检测 Codex 自身的完成提示文本
DONE_PATTERNS=(
  "^[[:space:]]*\\\$[[:space:]]*$"   # 普通 shell prompt: $
  "^[[:space:]]*>[[:space:]]*$"      # zsh/fish prompt: >
  "All changes applied"              # Codex 完成提示
  "Task completed"
  "Done"
)

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
  # 捕获 pane 最后 5 行内容
  PANE_CONTENT=$(tmux capture-pane -t "$WORKER_PANE" -p -S -5 2>/dev/null || true)

  for pattern in "${DONE_PATTERNS[@]}"; do
    if echo "$PANE_CONTENT" | grep -qE "$pattern"; then
      echo ""
      echo "✓ Codex 任务已完成！(用时 ${elapsed}s)"
      # macOS 通知（可选，失败不影响）
      if command -v osascript &>/dev/null; then
        osascript -e 'display notification "Codex 任务已完成" with title "SubAgent"' 2>/dev/null || true
      fi
      exit 0
    fi
  done

  # 进度指示
  printf "\r  等待中... %ds / %ds" "$elapsed" "$TIMEOUT"
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
done

echo ""
echo "⚠ 超时（${TIMEOUT}s）：Codex 可能仍在运行，请手动检查右侧 pane"
exit 1
