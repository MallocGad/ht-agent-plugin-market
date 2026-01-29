# Hook Payload 处理指南

## 概述

Claude Code 的 hooks 系统会通过 stdin 向脚本传递 JSON 格式的 payload，包含丰富的上下文信息。正确处理这些信息可以让通知更加智能和有用。

## Stop Hook Payload 结构

当任务停止时，Stop hook 会接收以下 JSON payload：

```json
{
  "session_id": "unique-session-identifier",
  "transcript_path": "/path/to/conversation/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "normal",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `session_id` | string | 唯一的会话标识符，用于跟踪任务状态 |
| `transcript_path` | string | 对话记录文件的完整路径 |
| `cwd` | string | 当前工作目录 |
| `permission_mode` | string | 权限模式（如 "normal"） |
| `hook_event_name` | string | Hook 事件名称（"Stop"） |
| `stop_hook_active` | boolean | Stop hook 是否激活 |

## 处理 Payload 的最佳实践

### 1. 从 stdin 读取 JSON

```bash
#!/bin/bash
# 读取完整的 JSON payload
INPUT=$(cat)

# 使用 jq 提取字段（推荐）
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
```

### 2. 提取对话摘要

从 transcript 文件中提取最后一条 assistant 消息：

```bash
extract_summary() {
    local transcript_path="$1"
    local max_length="${2:-100}"

    if [ ! -f "$transcript_path" ]; then
        return 1
    fi

    # 方法1: 如果是 JSON 格式
    local summary=$(jq -r '.. | objects | select(.role? == "assistant") | .text? // .content? // empty' "$transcript_path" 2>/dev/null | tail -1)

    # 方法2: 简单的文本提取（作为后备）
    if [ -z "$summary" ]; then
        summary=$(tail -n 50 "$transcript_path" | grep -v "^#" | grep -v "^$" | tail -1)
    fi

    # 截断到指定长度
    if [ -n "$summary" ]; then
        echo "$summary" | head -c "$max_length"
    fi
}
```

### 3. 错误处理

始终检查关键字段是否存在：

```bash
if [ -z "$session_id" ]; then
    # 使用环境变量或默认值作为后备
    session_id="${CLAUDE_SESSION_ID:-default}"
    log_warning "payload 中无 session_id，使用后备值"
fi
```

## 实现示例

参考以下文件了解完整实现：

1. **`task-complete.sh`** - 生产级实现，包含完整的错误处理
2. **`examples/complete-payload-example.sh`** - 简化的示例，展示基本用法
3. **`test-hook-payload.sh`** - 测试脚本，展示如何模拟 hook payload

## 测试你的实现

### 方法1: 使用提供的测试脚本

```bash
~/.claude/scripts/system-notify/test-hook-payload.sh
```

### 方法2: 手动测试

```bash
# 创建测试 payload
cat <<EOF | ~/.claude/scripts/system-notify/task-complete.sh
{
  "session_id": "test-123",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "$(pwd)",
  "permission_mode": "normal",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
EOF
```

## 常见问题

### Q: 为什么不使用命令行参数？

A: Hook payload 包含的信息量较大且结构复杂，使用 JSON 通过 stdin 传递更加灵活和可扩展。

### Q: 如何处理旧的 Claude Code 版本？

A: 在脚本中添加后备逻辑：

```bash
# 优先使用 payload
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# 后备到环境变量
if [ -z "$SESSION_ID" ]; then
    SESSION_ID="${CLAUDE_SESSION_ID:-default}"
fi
```

### Q: transcript 文件的格式是什么？

A: Transcript 格式可能因版本而异。建议使用宽松的解析策略，支持多种格式。参考 `task-complete.sh` 中的实现。

## 进阶技巧

### 1. 使用工作目录信息

```bash
CWD=$(echo "$INPUT" | jq -r '.cwd')
PROJECT_NAME=$(basename "$CWD")

# 在通知中显示项目名称
osascript -e "display notification \"任务完成\" with title \"$PROJECT_NAME\""
```

### 2. 基于权限模式的不同行为

```bash
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode')

if [ "$PERMISSION_MODE" = "restricted" ]; then
    # 在受限模式下使用更保守的通知
    echo "简化通知"
fi
```

### 3. 结合 session_id 进行任务追踪

```bash
# 记录任务完成到数据库或文件
echo "$SESSION_ID,$TIMESTAMP,$DURATION" >> ~/.claude/task-history.csv
```

## 参考资源

- [Claude Code Hooks 文档](https://docs.anthropic.com/claude-code/hooks)
- [jq 手册](https://stedolan.github.io/jq/manual/)
- [Bash 脚本最佳实践](https://google.github.io/styleguide/shellguide.html)
