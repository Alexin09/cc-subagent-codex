# cc-subagent-codex

> Use free Codex as a coding subagent for Claude Code / OpenCode — run parallel tasks while keeping your main conversation uninterrupted.

[English](#english) | 中文

---

## 让 AI 帮你安装（最省事）

把下面这段复制，直接粘贴给你的 Claude Code 或 OpenCode 发送，它会自动完成所有安装步骤：

```
帮我安装 cc-subagent-codex：
1. 确认 tmux 是否已安装，没有就用 brew install tmux 安装
2. 确认 codex 是否已安装，没有就用 npm install -g @openai/codex 安装
3. 在 ~/cc-subagent-codex 目录 clone 这个仓库：https://github.com/YOUR_USERNAME/cc-subagent-codex.git
4. 运行 bash ~/cc-subagent-codex/install.sh
5. 在 ~/.zshrc 中确认 cc-subcodex 命令已注册
6. 告诉我安装是否成功，以及如何启动
```

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

## 快速安装

**第一步：安装依赖**

```bash
brew install tmux
npm install -g @openai/codex
```

> Codex 需要 OpenAI 账号，免费账号即可使用 GPT-4o 额度。

**第二步：安装本项目**

```bash
git clone https://github.com/YOUR_USERNAME/cc-subagent-codex.git
cd cc-subagent-codex
bash install.sh
source ~/.zshrc   # 或重开终端
```

完成。`install.sh` 自动注册 `cc-subcodex` 命令，并将 Skill 安装到 Claude Code 和 OpenCode 的识别路径下。

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

## Let AI install it for you (easiest)

Copy the prompt below and paste it into Claude Code or OpenCode — it will handle everything automatically:

```
Help me install cc-subagent-codex:
1. Check if tmux is installed, install with brew install tmux if not
2. Check if codex is installed, install with npm install -g @openai/codex if not
3. Clone this repo to ~/cc-subagent-codex: https://github.com/YOUR_USERNAME/cc-subagent-codex.git
4. Run bash ~/cc-subagent-codex/install.sh
5. Confirm the cc-subcodex command is registered in ~/.zshrc
6. Tell me if installation succeeded and how to get started
```

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

## Quick Install

**Step 1: Install dependencies**

```bash
brew install tmux
npm install -g @openai/codex
```

> Codex requires an OpenAI account. The free tier includes GPT-4o usage.

**Step 2: Install this project**

```bash
git clone https://github.com/YOUR_USERNAME/cc-subagent-codex.git
cd cc-subagent-codex
bash install.sh
source ~/.zshrc   # or open a new terminal
```

Done. `install.sh` registers the `cc-subcodex` command and installs the Skill into the paths recognized by both Claude Code and OpenCode.

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
