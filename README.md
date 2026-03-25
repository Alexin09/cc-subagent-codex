# cc-subagent-codex

> Use free Codex as a coding subagent for Claude Code / OpenCode — run parallel tasks while keeping your main conversation uninterrupted.

[English](#english) | 中文

https://github.com/user-attachments/assets/d6e1b78e-0e23-4284-a16b-94e94ce4c694

---

## 为什么需要这个

Claude Code 用久了会碰到一个现实问题：**token 消耗快，Claude Opus 太贵用来干小活**。

但很多编码任务其实不需要 Opus 级别的推理——写脚本、实现工具函数、生成样板代码，这些交给 Codex 完全够用，而且 Codex 的免费额度非常慷慨。

cc-subagent-codex 让你的 Claude Code / OpenCode 把这类任务**自动分配给 Codex**，并行跑在右侧分屏里，你在左边继续对话，右边能看到 Codex 在实际执行：

```
┌──────────────────────┬──────────────────────┐
│                      │  subagent-1 (Codex)  │
│  Claude / OpenCode   ├──────────────────────┤
│                      │  subagent-2 (Codex)  │
│  你跟主 AI 对话      ├──────────────────────┤
│  它负责规划和验证    │  ░░░▓▓███  进度条    │
└──────────────────────┴──────────────────────┘
```

**核心优势：**

- **省 token**：简单编码任务交给 Codex，Claude 专注规划和验证
- **并行执行**：多个独立任务同时跑，不用一个一个等
- **可视化**：右侧实时看到每个 Subagent 在干什么，进度条监控
- **零干扰**：只在 tmux 环境下生效，正常打开 Claude Code 完全不受影响

---

## 安装

```bash
npx cc-subagent-codex
```

一条命令完成全部安装，包括依赖检查、Skill 注册、命令配置。

> 前置依赖：[tmux](https://github.com/tmux/tmux)（`brew install tmux`）和 [Codex CLI](https://github.com/openai/codex)（`npm install -g @openai/codex`，需要 OpenAI 免费账号）

---
## 手动安装

如果不想用 npx，也可以手动：

```bash
brew install tmux
npm install -g @openai/codex
git clone https://github.com/Alexin09/cc-subagent-codex.git
cd cc-subagent-codex && bash install.sh && source ~/.zshrc
```

---

## 使用

**启动工作界面：**

```bash
cc-subcodex           # 启动（自动识别 claude / opencode）
cc-subcodex --fresh   # 清除上次会话，全新开始
```

**在 AI 对话中触发：**

```
/codex-subagent 帮我在 ~/myproject/ 写三个独立工具：
1. 日志清理脚本
2. 配置文件校验器  
3. 健康检查脚本
```

AI 会自动规划、拆分任务、并行派发给多个 Codex Subagent，左侧显示 Todo 进度，右侧看到实际执行过程。

**正常使用 Claude Code 时不需要做任何改变**，不进 tmux 就不会触发 Subagent 模式。

---

## 工作流程

```
你的需求
  ↓
Claude / OpenCode（左侧）
  规划 → 拆分成独立子任务 → 输出 Todo 列表
  ↓
并行派发给 Codex Subagent（右侧）
  subagent-1: 写工具A ████░░ 60%
  subagent-2: 写工具B ██░░░░ 30%
  subagent-3: 写工具C ██████ 完成 ✓
  ↓
Claude 验证结果，汇报给你
```

---

## 文件结构

```
cc-subagent-codex/
├── install.sh                  # 一键安装
├── scripts/
│   ├── start.sh                # 启动 tmux 工作界面（cc-subcodex 命令的实体）
│   ├── codex-dispatch.sh       # 核心：派发任务给 Subagent
│   ├── progress-monitor.sh     # 右下角实时进度条
│   └── wait-for-completion.sh  # 等待任务完成
└── skills/
    └── codex-subagent/
        └── SKILL.md            # AI Skill 定义（Claude Code + OpenCode 通用）
```

---

## 兼容性

| | Claude Code | OpenCode | macOS | Linux |
|--|--|--|--|--|
| 支持 | ✅ | ✅ | ✅ | ✅ |

---

## 常见问题

**AI 没有触发 Subagent 模式**

确认是在 `cc-subcodex` 启动的 tmux 界面里操作，且使用了 `/codex-subagent` 前缀或明确提到"让 Codex 帮我做"。

**进度显示不准确**

进度检测基于 Codex TUI 的输出特征，属于已知限制，见 [SUPERVISION.md](SUPERVISION.md)。

**codex 命令未找到**

```bash
npm install -g @openai/codex
```

---

---

<a name="english"></a>

# cc-subagent-codex

> Use free Codex as a coding subagent for Claude Code / OpenCode — run parallel tasks while keeping your main conversation uninterrupted.

https://github.com/user-attachments/assets/d6e1b78e-0e23-4284-a16b-94e94ce4c694

---

## Install

```bash
npx cc-subagent-codex
```

One command. Handles everything — dependency checks, Skill registration, command setup.

> Prerequisites: [tmux](https://github.com/tmux/tmux) (`brew install tmux`) and [Codex CLI](https://github.com/openai/codex) (`npm install -g @openai/codex`, free OpenAI account required)

---

## Why this exists

Claude Code is powerful, but **token costs add up fast** — especially when Claude Opus is doing simple coding work that doesn't require its full capabilities.

Codex handles boilerplate scripts, standalone tools, and file generation just fine, and its free tier is generous. cc-subagent-codex lets your Claude Code / OpenCode **automatically delegate these tasks to Codex**, running them in parallel in a split terminal while you keep talking to Claude on the left.

```
┌──────────────────────┬──────────────────────┐
│                      │  subagent-1 (Codex)  │
│  Claude / OpenCode   ├──────────────────────┤
│                      │  subagent-2 (Codex)  │
│  you chat here       ├──────────────────────┤
│  AI plans & verifies │  ░░░▓▓███  progress  │
└──────────────────────┴──────────────────────┘
```

**Key benefits:**

- **Save tokens**: Let Codex handle mechanical coding work, Claude focuses on planning and verification
- **Parallel execution**: Multiple independent tasks run simultaneously
- **Visible**: Watch each Subagent work in real time with progress bars
- **Non-intrusive**: Only activates inside tmux — your normal Claude Code workflow is unchanged

---

## Manual install

If you prefer not to use npx:

```bash
brew install tmux
npm install -g @openai/codex
git clone https://github.com/Alexin09/cc-subagent-codex.git
cd cc-subagent-codex && bash install.sh && source ~/.zshrc
```

---

## Usage

**Launch the workspace:**

```bash
cc-subcodex           # auto-detects claude or opencode
cc-subcodex --fresh   # clear previous session and start fresh
```

**Trigger in the AI conversation:**

```
/codex-subagent Build three independent tools in ~/myproject/:
1. Log cleanup script
2. Config file validator
3. Health check script
```

The AI plans the work, splits it into subtasks, dispatches them to parallel Codex Subagents, shows a Todo list on the left, and verifies results when done.

**No changes needed for normal Claude Code usage** — without tmux, Subagent mode never activates.

---

## How it works

```
Your request
  ↓
Claude / OpenCode (left panel)
  Plan → split into independent subtasks → print Todo list
  ↓
Dispatch to Codex Subagents in parallel (right panels)
  subagent-1: tool A  ████░░ 60%
  subagent-2: tool B  ██░░░░ 30%
  subagent-3: tool C  ██████ done ✓
  ↓
Claude verifies and reports back
```

---

## Compatibility

| | Claude Code | OpenCode | macOS | Linux |
|--|--|--|--|--|
| Supported | ✅ | ✅ | ✅ | ✅ |

---

## Troubleshooting

**Subagent mode not triggering**

Make sure you're inside the tmux workspace launched by `cc-subcodex`, and use the `/codex-subagent` prefix or explicitly say "let Codex handle this".

**Progress bar inaccurate**

Progress detection is based on Codex TUI output patterns — a known limitation. See [SUPERVISION.md](SUPERVISION.md).

**`codex` command not found**

```bash
npm install -g @openai/codex
```
