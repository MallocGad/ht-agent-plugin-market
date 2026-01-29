#!/usr/bin/env bash
# scripts/task-start.sh
# UserPromptSubmit hook - 记录任务开始时间

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main() {
    # 从 stdin 读取 JSON payload
    local payload=$(cat)

    if [ -z "$payload" ]; then
        log_error "未收到 payload 数据"
        exit 1
    fi

    # 检查 jq 是否可用
    if ! command -v jq &> /dev/null; then
        log_error "jq 未安装，无法解析 JSON payload"
        exit 1
    fi

    # 从 payload 中提取 session_id（必须有）
    local session_id=$(echo "$payload" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -z "$session_id" ]; then
        log_error "payload 中缺少必需的 session_id 字段"
        exit 1
    fi

    # 从 payload 中提取 prompt（必须有）
    local prompt=$(echo "$payload" | jq -r '.prompt // empty' 2>/dev/null)
    if [ -z "$prompt" ]; then
        log_error "payload 中缺少必需的 prompt 字段"
        exit 1
    fi

    # 生成时间戳
    local timestamp=$(date +%s)

    # 清理提示中的特殊字符
    prompt=$(echo "$prompt" | tr -d '\n\r' | sed 's/"/\\"/g')

    # 创建状态文件
    # 确保 tmp 目录存在
    mkdir -p "$TMP_DIR" 2>/dev/null || true
    local state_file="$TMP_DIR/claude-task-${session_id}.json"

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
        exit 1
    fi
}

main "$@"
