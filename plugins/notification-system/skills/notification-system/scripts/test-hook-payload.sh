#!/usr/bin/env bash
# scripts/test-hook-payload.sh
# 测试完整的 hook payload 格式

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

echo "=========================================="
echo "测试 Hook Payload 格式"
echo "=========================================="
echo ""

# 创建一个模拟的 transcript 文件
TEMP_TRANSCRIPT="/tmp/test-transcript-$$.json"
cat > "$TEMP_TRANSCRIPT" <<'EOF'
{
  "messages": [
    {
      "role": "user",
      "content": "帮我分析这段代码的性能问题"
    },
    {
      "role": "assistant",
      "text": "我已经分析了代码，发现主要的性能瓶颈在数据库查询部分。建议添加索引和使用批量查询优化。"
    }
  ]
}
EOF

# 模拟 Stop hook 的 payload
TEST_PAYLOAD=$(cat <<EOF
{
  "session_id": "test-session-$(date +%s)",
  "transcript_path": "$TEMP_TRANSCRIPT",
  "cwd": "$(pwd)",
  "permission_mode": "normal",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
EOF
)

echo "1. 创建测试状态文件（模拟任务开始）..."
# 先模拟 task-start.sh 创建状态文件
SESSION_ID=$(echo "$TEST_PAYLOAD" | jq -r '.session_id')
STATE_FILE="$TMP_DIR/claude-task-${SESSION_ID}.json"

# 确保目录存在
mkdir -p "$TMP_DIR" 2>/dev/null || true

# 创建状态文件（任务开始时间为 2 分钟前）
START_TIME=$(($(date +%s) - 120))
cat > "$STATE_FILE" <<EOF
{
  "startTime": $START_TIME,
  "prompt": "帮我分析这段代码的性能问题"
}
EOF

echo "✓ 状态文件已创建: $STATE_FILE"
echo ""

echo "2. 发送模拟的 Stop hook payload..."
echo "$TEST_PAYLOAD" | jq '.'
echo ""

echo "3. 调用 task-complete.sh..."
echo "$TEST_PAYLOAD" | "$SCRIPT_DIR/task-complete.sh"

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo ""
echo "请检查："
echo "1. 是否收到通知"
echo "2. 通知内容是否包含从 transcript 提取的摘要"
echo "3. 日志文件: $LOG_FILE"
echo ""

# 清理临时文件
rm -f "$TEMP_TRANSCRIPT"
