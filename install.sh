#!/usr/bin/env bash
# install.sh — cc-subagent-codex 一键安装
# 用法: bash install.sh

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_RC=""
GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"; BOLD="\033[1m"

info()  { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}!${RESET} %s\n" "$*"; }
step()  { printf "\n${BOLD}%s${RESET}\n" "$*"; }

step "cc-subagent-codex 安装"

# ── 1. 检测 shell 配置文件 ────────────────────────────────────────────────────
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
  SHELL_RC="$HOME/.bash_profile"
else
  warn "未找到 shell 配置文件，跳过命令注册"
fi

# ── 2. 脚本执行权限 ───────────────────────────────────────────────────────────
chmod +x "$REPO_DIR"/scripts/*.sh
info "脚本权限设置完成"

# ── 3. 安装 Skill（写入实际路径） ─────────────────────────────────────────────
# 同时安装到两个路径，覆盖 OpenCode 和 Claude Code
for SKILL_DIR in \
  "$HOME/.agents/skills/codex-subagent" \
  "$HOME/.config/opencode/skills/codex-subagent" \
  "$HOME/.claude/skills/codex-subagent"
do
  mkdir -p "$SKILL_DIR"
  # 替换 SKILL.md 里的硬编码路径为当前实际路径
  sed "s|/Users/ale.x/xhs_research/githubResearch/260324/cc-subagent-codex|${REPO_DIR}|g" \
    "$REPO_DIR/skills/codex-subagent/SKILL.md" > "$SKILL_DIR/SKILL.md"
done
info "Skill 已安装到 ~/.agents/skills/ 和 ~/.config/opencode/skills/ 和 ~/.claude/skills/"

# ── 4. 注册 cc-subcodex 命令 ──────────────────────────────────────────────────
ALIAS_LINE="alias cc-subcodex='bash ${REPO_DIR}/scripts/start.sh'"
MARKER="# cc-subagent-codex"

if [[ -n "$SHELL_RC" ]]; then
  # 删除旧的（如果有），再写新的
  if grep -q "$MARKER" "$SHELL_RC" 2>/dev/null; then
    # 删掉旧的两行（marker + alias）
    grep -v "$MARKER" "$SHELL_RC" | grep -v "alias cc-subcodex=" > "$SHELL_RC.tmp" && mv "$SHELL_RC.tmp" "$SHELL_RC"
  fi
  printf "\n%s\n%s\n" "$MARKER" "$ALIAS_LINE" >> "$SHELL_RC"
  info "命令 cc-subcodex 已注册到 $SHELL_RC"
  warn "请运行: source $SHELL_RC  （或重开终端生效）"
fi

# ── 5. 检查依赖 ───────────────────────────────────────────────────────────────
step "依赖检查"

check_dep() {
  local cmd="$1" install_hint="$2"
  if command -v "$cmd" &>/dev/null; then
    info "$cmd 已安装 ($(command -v "$cmd"))"
  else
    warn "$cmd 未安装  →  $install_hint"
  fi
}

check_dep tmux   "brew install tmux"
check_dep codex  "npm install -g @openai/codex"
check_dep opencode "npm install -g opencode-ai   （OpenCode 用户）"
check_dep claude   "npm install -g @anthropic-ai/claude-code   （Claude Code 用户）"

step "安装完成"
echo ""
echo "  使用方式："
echo "    cc-subcodex              # 启动 SubAgent 工作界面（自动检测 opencode / claude）"
echo "    cc-subcodex --fresh      # 全新开始（清除上次会话）"
echo ""
echo "  在 AI 对话中触发 Subagent："
echo "    直接描述需求，AI 会自动判断是否启用并行 Subagent"
echo "    或输入 /codex-subagent 显式调用"
echo ""
