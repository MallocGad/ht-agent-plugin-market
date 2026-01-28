#!/usr/bin/env bash
# scripts/task-start.sh
# UserPromptSubmit hook - 记录任务开始时间

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main() {
    # 从环境变量获取 session ID，如果不存在则使用默认值
    local session_id="${CLAUDE_SESSION_ID:-default}"

    if [ -z "$CLAUDE_SESSION_ID" ]; then
        log_warning "CLAUDE_SESSION_ID 环境变量未设置，使用默认 session ID: $session_id"
    fi

    # 从 stdin 读取 JSON payload
    local payload=$(cat)

    if [ -z "$payload" ]; then
        log_error "未收到 payload 数据"
        exit 0
    fi

    # 提取时间戳和提示
    local timestamp=$(echo "$payload" | get_json_value - "timestamp")
    local prompt=$(echo "$payload" | get_json_value - "prompt")

    # 验证 prompt 是否成功提取（必须有）
    if [ -z "$prompt" ]; then
        log_error "无法从 payload 提取 prompt 字段"
        exit 0
    fi

    # 如果没有时间戳，使用当前时间
    if [ -z "$timestamp" ]; then
        timestamp=$(date +%s)
        log_warning "payload 中无 timestamp，使用当前时间"
    fi

    # 清理提示中的特殊字符
    prompt=$(echo "$prompt" | tr -d '\n\r' | sed 's/"/\\"/g')

    # 创建状态文件
    local state_file="/tmp/claude-task-${session_id}.json"

    cat > "$state_file" <<EOF
{
  "startTime": $timestamp,
  "prompt": "$prompt"
}
EOF

    if [ -f "$state_file" ]; then
        log_info "任务开始: session=$session_id, timestamp=$timestamp"
    else
        log_error "创建状态文件失败: $state_file"
    fi
}

main "$@"
