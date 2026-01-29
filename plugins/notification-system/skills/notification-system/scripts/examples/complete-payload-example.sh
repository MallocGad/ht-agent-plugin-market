#!/bin/bash
# 示例：完整的 Stop hook payload 处理脚本
# 这个脚本展示了如何处理 Claude Code Stop hook 提供的所有信息

# 从 stdin 读取 JSON payload
INPUT=$(cat)

# 提取所有可用参数
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // empty')
HOOK_EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // empty')

# 从对话记录中提取最后一条 assistant 消息作为摘要
SUMMARY=""
if [ -f "$TRANSCRIPT_PATH" ]; then
  # 方法1: 如果 transcript 是 JSON 格式
  SUMMARY=$(jq -r '.. | objects | select(.role? == "assistant") | .text? // .content? // empty' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | head -c 100)

  # 方法2: 如果上面失败，尝试简单的文本提取
  if [ -z "$SUMMARY" ]; then
    SUMMARY=$(tail -n 20 "$TRANSCRIPT_PATH" | grep -o '"text":"[^"]*"' | tail -n 1 | sed 's/"text":"//;s/"$//' | head -c 100)
  fi
fi

# 构造通知消息
MESSAGE="会话ID: $SESSION_ID
工作目录: $CWD
权限模式: $PERMISSION_MODE
事件名称: $HOOK_EVENT_NAME
Stop Hook激活: $STOP_HOOK_ACTIVE
对话记录: $TRANSCRIPT_PATH
摘要: ${SUMMARY:-无}"

# 发送 macOS 通知
osascript -e "display notification \"$MESSAGE\" with title \"Claude Code 已完成\" subtitle \"任务执行完成\""

# 可选：记录日志
LOG_FILE="$HOME/.claude/scripts/system-notify/logs/custom-notification.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session: $SESSION_ID, Event: $HOOK_EVENT_NAME" >> "$LOG_FILE"
echo "  Summary: ${SUMMARY:-无}" >> "$LOG_FILE"
