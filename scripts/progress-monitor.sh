#!/usr/bin/env bash
# progress-monitor.sh — 实时显示所有 Codex subagent 进度
# 由 start.sh 自动在右下角 pane 启动

set -u

STATE_DIR="/tmp/codex-subagents"
REFRESH=2

RESET="\033[0m"; BOLD="\033[1m"; GREEN="\033[32m"
YELLOW="\033[33m"; CYAN="\033[36m"; DIM="\033[2m"
RED="\033[31m"; BLUE="\033[34m"
BAR_WIDTH=18

draw_bar() {
  local pct="$1" bar="" i
  local filled=$(( BAR_WIDTH * pct / 100 ))
  local empty=$(( BAR_WIDTH - filled ))
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf '%s' "$bar"
}

read_state() {
  local file="$1"
  SUBAGENT_NUM=""; PANE_ID=""; TASK_NAME=""; STATUS=""; STARTED_AT=""
  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    val="${val%\"}"; val="${val#\"}"
    case "$key" in
      SUBAGENT_NUM)  SUBAGENT_NUM="$val" ;;
      PANE_ID)     PANE_ID="$val" ;;
      TASK_NAME)   TASK_NAME="$val" ;;
      STATUS)      STATUS="$val" ;;
      STARTED_AT)  STARTED_AT="$val" ;;
    esac
  done < "$file"
}

# ── 核心：通过 pane 内容判断真实状态 ─────────────────────────────────────────
# codex 交互式进程完成后不会退出，pane_current_command 永远是 node
# 唯一可靠信号：pane 内容
#
# 运行中的特征：含 "Working" 或最后几行有 "• "（步骤执行行）
# 完成的特征：
#   1. 含 "› " 空闲 prompt（codex 等待下一条输入）
#   2. 且不含 "Working"
# 失败特征：含 "error:" / "Error:" / "zsh: event not found"
# 启动中：含 "Do you trust" 或 "loading"
detect_pane_status() {
  local pane_id="$1"

  # pane 不存在（用 -F 固定字符串，避免 % 被 grep 当特殊字符）
  if ! tmux list-panes -F '#{pane_id}' 2>/dev/null | grep -qF "${pane_id}"; then
    echo "error"; return
  fi

  local content
  content=$(tmux capture-pane -t "$pane_id" -p -S -80 2>/dev/null || true)

  # 启动中：只看最后 5 行，避免历史输出里的 "loading" 误判
  local last5
  last5=$(echo "$content" | tail -5)
  if echo "$last5" | grep -q "Do you trust\|model:.*loading"; then
    echo "starting"; return
  fi

  # 失败
  if echo "$content" | grep -qE "zsh: event not found|command not found.*codex"; then
    echo "failed"; return
  fi

  # 正在工作：只有 "Working" 动画行是活跃信号
  # "• " 开头是已完成步骤记录，不代表还在运行
  if echo "$content" | grep -qF "Working"; then
    echo "running"; return
  fi

  # 完成：出现 codex 的空闲 prompt
  # › 是 U+203A，在 pane 里有缩进，不在行首，用 grep -F 匹配子串
  if echo "$content" | grep -qF "› "; then
    echo "done"; return
  fi

  # 补充完成判断：有步骤记录（• ）但没有 Working → 也是完成
  if echo "$content" | grep -qF "• "; then
    echo "done"; return
  fi

  # 其他情况（codex 刚启动还没输出）
  echo "starting"
}

estimate_progress() {
  local pane_id="$1" resolved="$2"
  case "$resolved" in
    done|success) echo 100; return ;;
    failed|error) echo 0;   return ;;
    starting)     echo 5;   return ;;
  esac
  # running：数步骤行估算
  local content steps pct
  content=$(tmux capture-pane -t "$pane_id" -p -S -80 2>/dev/null || true)
  steps=$(echo "$content" | grep -c "^• " 2>/dev/null || echo 0)
  pct=$(( 10 + steps * 10 ))
  [[ $pct -gt 85 ]] && pct=85
  echo $pct
}

# ── 主循环 ────────────────────────────────────────────────────────────────────
tput civis 2>/dev/null || true          # 隐藏光标，避免闪烁
trap 'tput cnorm 2>/dev/null || true' EXIT  # 退出时恢复光标
clear                                   # 初始化时清屏一次

while true; do
  tput cup 0 0 2>/dev/null || true      # 光标移到左上角，原地覆盖
  printf "${BOLD}${CYAN}  Codex Subagents${RESET}\n"
  printf "${DIM}  %s  (每 %ds 刷新)${RESET}\n\n" "$(date '+%H:%M:%S')" "$REFRESH"

  mkdir -p "$STATE_DIR"
  FOUND=0

  for state_file in "$STATE_DIR"/subagent-*.state; do
    [[ -f "$state_file" ]] || continue
    FOUND=1

    read_state "$state_file"

    # 如果 state 文件已经是终态，直接用；否则从 pane 内容实时检测
    case "$STATUS" in
      done|failed)
        RESOLVED="$STATUS"
        ;;
      *)
        RESOLVED=$(detect_pane_status "$PANE_ID")
        # 检测到完成/失败时，同步写回 state 文件（monitor 负责回写）
        if [[ "$RESOLVED" == "done" && "$STATUS" != "done" ]]; then
          sed -i '' "s/STATUS=\"${STATUS}\"/STATUS=\"done\"/" "$state_file" 2>/dev/null || true
        elif [[ "$RESOLVED" == "failed" && "$STATUS" != "failed" ]]; then
          sed -i '' "s/STATUS=\"${STATUS}\"/STATUS=\"failed\"/" "$state_file" 2>/dev/null || true
        fi
        ;;
    esac

    PCT=$(estimate_progress "$PANE_ID" "$RESOLVED")
    BAR=$(draw_bar "$PCT")
    TASK_SHORT="${TASK_NAME:0:30}"
    [[ ${#TASK_NAME} -gt 30 ]] && TASK_SHORT+="…"

    case "$RESOLVED" in
      running)
        printf "  ${YELLOW}${BOLD}subagent-%-1s${RESET}  ${YELLOW}⟳  %s${RESET}  %d%%\n" \
          "$SUBAGENT_NUM" "$BAR" "$PCT"
        printf "  ${DIM}    %s${RESET}\n" "$TASK_SHORT"
        printf "  ${DIM}    开始 %s${RESET}\n\n" "${STARTED_AT:-?}"
        ;;
      done)
        printf "  ${GREEN}${BOLD}subagent-%-1s${RESET}  ${GREEN}✓  %s${RESET}  100%%\n" \
          "$SUBAGENT_NUM" "$BAR"
        printf "  ${DIM}    %s${RESET}\n\n" "$TASK_SHORT"
        ;;
      failed)
        printf "  ${RED}${BOLD}subagent-%-1s${RESET}  ${RED}✗  %s${RESET}  失败\n" \
          "$SUBAGENT_NUM" "$BAR"
        printf "  ${DIM}    %s${RESET}\n\n" "$TASK_SHORT"
        ;;
      starting)
        printf "  ${BLUE}${BOLD}subagent-%-1s${RESET}  ${BLUE}…  %s${RESET}  启动中\n" \
          "$SUBAGENT_NUM" "$BAR"
        printf "  ${DIM}    %s${RESET}\n\n" "$TASK_SHORT"
        ;;
      error)
        printf "  ${RED}${BOLD}subagent-%-1s${RESET}  ${RED}!  %s${RESET}  pane 丢失\n" \
          "$SUBAGENT_NUM" "$BAR"
        printf "  ${DIM}    %s${RESET}\n\n" "$TASK_SHORT"
        ;;
    esac
  done

  if [[ "$FOUND" -eq 0 ]]; then
    printf "  ${DIM}等待任务派发...${RESET}\n\n"
    printf "  ${DIM}在左侧说：「让 Codex 帮我做 ___」${RESET}\n"
  fi

  tput ed 2>/dev/null || true           # 清除光标到屏幕末尾的旧内容
  sleep "$REFRESH"
done
