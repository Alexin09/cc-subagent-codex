---
name: codex-subagent
description: 把编码任务派发给 Codex Subagent 并行执行。仅在检测到 tmux 环境时生效。用户说"让 Codex 帮我做"、"用 Codex 实现"、"帮我写/实现 XXX 工具/脚本"，或给出多个独立编码任务时触发。正常使用 Claude/OpenCode（无 tmux）时忽略此 Skill。
---

# Codex SubAgent 并行调度

## 第一步：检查是否在 tmux 内

```bash
echo ${TMUX:-NOT_IN_TMUX}
```

**如果输出 `NOT_IN_TMUX`，立即停止，不要继续**。告知用户：
> 当前不在 tmux 环境中，Subagent 模式不可用。如需使用，请运行 `cc-subcodex` 启动工作界面。

**如果在 tmux 内，继续以下步骤。**

---

## 第二步：定位调度脚本

```bash
# 优先用环境变量（install.sh 会自动设置）
DISPATCH="${CODEX_DISPATCH:-}"

# 否则在常见位置查找
if [[ -z "$DISPATCH" ]]; then
  for candidate in \
    "$HOME/.local/share/cc-subagent-codex/scripts/codex-dispatch.sh" \
    "$HOME/cc-subagent-codex/scripts/codex-dispatch.sh" \
    "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo '.')")/../scripts/codex-dispatch.sh"
  do
    [[ -x "$candidate" ]] && DISPATCH="$candidate" && break
  done
fi

if [[ -z "$DISPATCH" ]]; then
  echo "错误: 找不到 codex-dispatch.sh，请重新运行 install.sh" >&2
  exit 1
fi
```

---

## 第三步：规划任务，输出 Todo 列表

收到需求后先规划，不要跳过。把目标拆成 2-4 个独立子任务，输出：

```
📋 任务计划
─────────────────────────────────────
⬜ [subagent-1] 子任务A（文件名：xxx.sh）
⬜ [subagent-2] 子任务B（文件名：yyy.sh）
⬜ [subagent-3] 子任务C（文件名：zzz.sh）
─────────────────────────────────────
开始并行派发...
```

---

## 第四步：判断并行 / 串行

**并行**：子任务互不依赖，各自输出独立文件 → 同时派发  
**串行**：任务 B 需要任务 A 的结果 → 依次派发

---

## 第五步：派发任务

**必须用 `--file` 传递任务内容，禁止在命令行直接拼任务字符串**（括号/中文会触发 syntax error）。

**并行派发：**

```bash
cat > /tmp/task1.txt << 'TASK'
任务A完整描述（可含括号、中文、引号）
TASK

cat > /tmp/task2.txt << 'TASK'
任务B完整描述
TASK

cat > /tmp/task3.txt << 'TASK'
任务C完整描述
TASK

"$DISPATCH" --file /tmp/task1.txt --subagent 1
"$DISPATCH" --file /tmp/task2.txt --subagent 2
"$DISPATCH" --file /tmp/task3.txt --subagent 3
```

**串行派发：**

```bash
cat > /tmp/task1.txt << 'TASK'
任务A描述
TASK
"$DISPATCH" --file /tmp/task1.txt --subagent 1
# 验证 A 完成后再派 B
cat > /tmp/task2.txt << 'TASK'
任务B描述
TASK
"$DISPATCH" --file /tmp/task2.txt --subagent 1
```

---

## 第六步：派发后更新 Todo

```
📋 任务进度
─────────────────────────────────────
✅ [subagent-1] 子任务A  已完成
⟳  [subagent-2] 子任务B  进行中
⟳  [subagent-3] 子任务C  进行中
─────────────────────────────────────
```

---

## 第七步：验证结果

Subagent 完成后由你验证（检查文件、运行脚本）。验证通过标记 ✅，有问题自己修复，不要再派给 Codex。

---

## 好的任务指令格式

包含：**做什么 + 保存到哪个文件 + 具体功能 + 数据格式**

示例：
> 用 shell 脚本实现财务记账工具，保存为 /path/to/ledger.sh。功能：add（记录收支，含金额/分类/备注）、list（列出记录）、delete（按 id 删除）。数据存到 ledger.json，字段：id、date、amount、category、note、type(income/expense)。

---

## 适合 Codex 的任务
- 写独立的脚本、工具、函数文件
- 需求明确、可独立验证的功能模块
- 多个互不依赖的文件

## 不适合 Codex 的任务
- 需要当前对话上下文的任务
- 架构设计和技术选型
- 有复杂先后依赖的重构
