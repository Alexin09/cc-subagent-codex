#!/usr/bin/env bash
# start.sh
# 一键启动完整 SubAgent 工作界面
#
# 布局：
#   ┌─────────────────────┬─────────────────────┐
#   │                     │  subagent-1 (Codex)   │
#   │  左：AI 主对话       ├─────────────────────┤
#   │  (OpenCode/Claude)  │  subagent-2 (Codex)   │
#   │                     ├─────────────────────┤
#   │                     │  progress monitor   │
#   └─────────────────────┴─────────────────────┘
#
# 用法:
#   ./scripts/start.sh                   # 自动检测 AI 工具，当前目录
#   ./scripts/start.sh ~/myproject       # 指定目录
#   ./scripts/start.sh . opencode        # 强制 OpenCode
#   ./scripts/start.sh . claude          # 强制 Claude Code
#   ./scripts/start.sh --fresh           # 全新开始，清除历史 session

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRESH=false
WORKDIR=""
AGENT_CMD=""
SESSION="subagent"

# 解析参数
for arg in "$@"; do
  case "$arg" in
    --fresh) FRESH=true ;;
    opencode|claude) AGENT_CMD="$arg" ;;
    *) [[ -z "$WORKDIR" ]] && WORKDIR="$arg" ;;
  esac
done
WORKDIR="${WORKDIR:-$(pwd)}"

# ── 自动检测 AI 工具 ──────────────────────────────────────────────────────────
if [[ -z "$AGENT_CMD" ]]; then
  if command -v opencode &>/dev/null; then
    AGENT_CMD="opencode"
  elif command -v claude &>/dev/null; then
    AGENT_CMD="claude"
  else
    echo "错误: 未找到 opencode 或 claude" >&2
    echo "  OpenCode:    npm install -g opencode-ai" >&2
    echo "  Claude Code: npm install -g @anthropic-ai/claude-code" >&2
    exit 1
  fi
fi

# ── 依赖检查 ─────────────────────────────────────────────────────────────────
for cmd in tmux codex "$AGENT_CMD"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "错误: 未找到 $cmd" >&2
    [[ "$cmd" == "tmux" ]]  && echo "  安装: brew install tmux" >&2
    [[ "$cmd" == "codex" ]] && echo "  安装: npm install -g @openai/codex" >&2
    exit 1
  fi
done

# 清理 subagent 状态
rm -f /tmp/codex-subagents/*.state 2>/dev/null || true

# ── --fresh：杀掉旧 session，全新开始 ────────────────────────────────────────
if $FRESH && tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux kill-session -t "$SESSION"
  echo "已清除旧 session，全新启动..."
fi

echo "启动 $AGENT_CMD SubAgent 界面..."

# ── 已有 session，直接 attach（保留历史） ─────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "已有 '$SESSION' session，直接进入（用 --fresh 可全新开始）..."
  exec tmux attach-session -t "$SESSION"
fi

# ── 获取终端尺寸 ─────────────────────────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 220)
ROWS=$(tput lines 2>/dev/null || echo 50)

# ── 新建 session ─────────────────────────────────────────────────────────────
tmux new-session -d -s "$SESSION" -x "$COLS" -y "$ROWS"

# 左侧：AI 主对话（占 55% 宽度）
tmux send-keys -t "$SESSION":0.0 "cd $(printf '%q' "$WORKDIR") && $AGENT_CMD" Enter

# 右侧：水平分割，右边占 45%
tmux split-window -t "$SESSION":0.0 -h -p 45

# 右侧上方：第一个 subagent 槽（待命提示）
tmux select-pane -t "$SESSION":0.1 -T "codex-subagent-1"
tmux send-keys -t "$SESSION":0.1 "cd $(printf '%q' "$WORKDIR")" Enter
tmux send-keys -t "$SESSION":0.1 "clear" Enter

# 右侧下方：progress monitor（占右侧下 30%）
tmux split-window -t "$SESSION":0.1 -v -p 30
tmux select-pane -t "$SESSION":0.2 -T "progress-monitor"
tmux send-keys -t "$SESSION":0.2 "bash $(printf '%q' "$SCRIPT_DIR/progress-monitor.sh")" Enter

# 焦点回到左侧 AI 主对话
tmux select-pane -t "$SESSION":0.0

exec tmux attach-session -t "$SESSION"
