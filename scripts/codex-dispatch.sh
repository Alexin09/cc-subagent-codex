#!/usr/bin/env bash
# codex-dispatch.sh — 派发任务给 Codex subagent pane
#
# 用法:
#   codex-dispatch.sh --file /tmp/task.txt              # 推荐：从文件读取任务
#   codex-dispatch.sh --file /tmp/task.txt --subagent 2
#   codex-dispatch.sh --list                            # 查看所有 subagent 状态

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/tmp/codex-subagents"
mkdir -p "$STATE_DIR"

# ── 参数解析 ─────────────────────────────────────────────────────────────────
SUBAGENT_ID=""
LIST_MODE=false
TASK_FILE_INPUT=""
TASK_ARGS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subagent) SUBAGENT_ID="$2"; shift 2 ;;
    --list)   LIST_MODE=true; shift ;;
    --file)   TASK_FILE_INPUT="$2"; shift 2 ;;
    *)        TASK_ARGS="${TASK_ARGS:+$TASK_ARGS }$1"; shift ;;
  esac
done

# ── list 模式 ────────────────────────────────────────────────────────────────
if $LIST_MODE; then
  echo "当前 subagent 状态："
  found=0
  for state_file in "$STATE_DIR"/subagent-*.state; do
    [[ -f "$state_file" ]] || continue
    found=1
    w_num=""; w_status=""; w_task=""
    while IFS='=' read -r key val; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      val="${val%\"}"; val="${val#\"}"
      case "$key" in
        SUBAGENT_NUM) w_num="$val" ;;
        STATUS)     w_status="$val" ;;
        TASK_NAME)  w_task="$val" ;;
      esac
    done < "$state_file"
    echo "  subagent-${w_num:-?}: [${w_status:-?}] ${w_task:-}"
  done
  [[ $found -eq 0 ]] && echo "  (无运行中的 subagent)"
  exit 0
fi

# ── 确定任务文件 ─────────────────────────────────────────────────────────────
TASK_FILE="/tmp/codex-task-$$.txt"

if [[ -n "$TASK_FILE_INPUT" ]]; then
  [[ ! -f "$TASK_FILE_INPUT" ]] && { echo "错误: 找不到任务文件: $TASK_FILE_INPUT" >&2; exit 1; }
  cp "$TASK_FILE_INPUT" "$TASK_FILE"
elif [[ -n "$TASK_ARGS" ]]; then
  printf '%s' "$TASK_ARGS" > "$TASK_FILE"
else
  echo "错误: 请提供任务描述或 --file 路径" >&2
  exit 1
fi

TASK_PREVIEW="$(head -c 80 "$TASK_FILE")"

# ── 环境检查 ─────────────────────────────────────────────────────────────────
if [[ -z "${TMUX:-}" ]]; then
  echo "错误: 请先运行 cc-subcodex 进入工作界面" >&2; exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "错误: 未找到 codex，安装: npm install -g @openai/codex" >&2; exit 1
fi

WORKDIR="$(pwd)"
ORIGIN_PANE="$(tmux display-message -p '#{pane_id}')"

# ── 自动分配 subagent 编号 ──────────────────────────────────────────────────────
if [[ -z "$SUBAGENT_ID" ]]; then
  for n in 1 2 3 4 5; do
    STATE_FILE="$STATE_DIR/subagent-${n}.state"
    if [[ ! -f "$STATE_FILE" ]]; then
      SUBAGENT_ID="$n"; break
    fi
    w_status=""
    while IFS='=' read -r key val; do
      [[ "$key" == "STATUS" ]] && w_status="${val//\"/}"
    done < "$STATE_FILE"
    if [[ "$w_status" != "running" ]]; then
      SUBAGENT_ID="$n"; break
    fi
  done
  if [[ -z "$SUBAGENT_ID" ]]; then
    echo "错误: 所有 subagent (1-5) 均在运行中" >&2; exit 1
  fi
fi

PANE_TITLE="codex-subagent-${SUBAGENT_ID}"
STATE_FILE="$STATE_DIR/subagent-${SUBAGENT_ID}.state"

# ── 找到或创建 subagent pane ───────────────────────────────────────────────────
EXISTING_PANE_ID=$(tmux list-panes -F '#{pane_id}:#{pane_title}' 2>/dev/null \
  | grep ":${PANE_TITLE}$" | head -1 | cut -d: -f1 || true)

if [[ -n "$EXISTING_PANE_ID" ]]; then
  TARGET_PANE="$EXISTING_PANE_ID"
else
  EXISTING_WORKERS=$(tmux list-panes -F '#{pane_title}' 2>/dev/null \
    | grep -c '^codex-subagent-' || true)
  if [[ "$EXISTING_WORKERS" -eq 0 ]]; then
    tmux split-window -h -p 45
  else
    LAST_SUBAGENT_PANE=$(tmux list-panes -F '#{pane_id}:#{pane_title}' 2>/dev/null \
      | grep ':codex-subagent-' | tail -1 | cut -d: -f1)
    tmux select-pane -t "$LAST_SUBAGENT_PANE"
    tmux split-window -v -p 50
  fi
  tmux select-pane -T "$PANE_TITLE"
  TARGET_PANE="$(tmux display-message -p '#{pane_id}')"
  tmux send-keys -t "$TARGET_PANE" "cd $(printf '%q' "$WORKDIR")" Enter
  sleep 0.3
  tmux select-pane -t "$ORIGIN_PANE"
fi

# ── 修复1: 关掉 zsh history expansion，防止 ! 触发 event not found ────────────
# setopt NO_BANG_HIST 针对 zsh；set +H 针对 bash（两条都发，shell 自己忽略不认识的）
tmux send-keys -t "$TARGET_PANE" "setopt NO_BANG_HIST 2>/dev/null; set +H 2>/dev/null" Enter
sleep 0.3

# ── 写 state 文件（标记 running） ────────────────────────────────────────────
TASK_NAME_SAFE="$(head -c 50 "$TASK_FILE" | tr '"\\!>' "' __")"
cat > "$STATE_FILE" <<EOF
SUBAGENT_NUM="${SUBAGENT_ID}"
PANE_ID="${TARGET_PANE}"
PANE_TITLE="${PANE_TITLE}"
TASK_NAME="${TASK_NAME_SAFE}"
STATUS="running"
STARTED_AT="$(date '+%H:%M:%S')"
WORKDIR="${WORKDIR}"
EOF

# ── 修复3: 状态回写 —— codex 完成或失败后自动更新 state 文件 ─────────────────
# 用 && / || 捕获 codex 退出码，写回 done 或 failed
# 任务通过文件传入，$(cat file) 在 subagent pane 的 shell 里展开，不经过当前 shell
tmux send-keys -t "$TARGET_PANE" \
  "codex exec --sandbox danger-full-access \"\$(cat $(printf '%q' "$TASK_FILE"))\" \
   && sed -i '' 's/STATUS=\"running\"/STATUS=\"done\"/' $(printf '%q' "$STATE_FILE") \
   || sed -i '' 's/STATUS=\"running\"/STATUS=\"failed\"/' $(printf '%q' "$STATE_FILE")" \
  Enter

# ── 自动确认信任弹窗 ─────────────────────────────────────────────────────────
for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 1
  PANE_CONTENT=$(tmux capture-pane -t "$TARGET_PANE" -p 2>/dev/null || true)
  if echo "$PANE_CONTENT" | grep -q "Do you trust"; then
    tmux send-keys -t "$TARGET_PANE" "" Enter
    break
  fi
done

# ── 修复2: 探活检查 —— 等 codex 进程真正启动 ─────────────────────────────────
echo "  等待 codex 进程启动..."
STARTED=false
for i in 1 2 3 4 5 6 7 8; do
  sleep 1
  CURRENT_CMD=$(tmux display-message -t "$TARGET_PANE" -p '#{pane_current_command}' 2>/dev/null || true)
  if [[ "$CURRENT_CMD" == "node" || "$CURRENT_CMD" == "codex" ]]; then
    STARTED=true
    break
  fi
done

if ! $STARTED; then
  # 探活失败：更新 state，打印 pane 内容便于诊断
  sed -i '' 's/STATUS="running"/STATUS="failed"/' "$STATE_FILE" 2>/dev/null || true
  echo "✗ subagent-${SUBAGENT_ID} 启动失败" >&2
  echo "  pane 内容：" >&2
  tmux capture-pane -t "$TARGET_PANE" -p -S -10 >&2 || true
  exit 1
fi

echo "✓ subagent-${SUBAGENT_ID} 已确认启动 (codex 进程运行中)"
echo "  任务: ${TASK_PREVIEW}"
echo "  目录: ${WORKDIR}"
echo "  Pane: ${TARGET_PANE}"
