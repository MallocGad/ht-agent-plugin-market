#!/usr/bin/env bash
# scripts/task-start.sh
# UserPromptSubmit hook - 记录任务开始时间或重置静默计时器

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

    # 初始化状态目录
    init_state_dir

    # 获取当前时间戳
    local current_time=$(get_current_timestamp)

    # 检查状态文件是否已存在
    local state_file=$(get_state_file_path "$session_id")

    if [ -f "$state_file" ]; then
        # 状态文件已存在 - 这是用户的后续输入
        # 重置静默计时器和通知标记，更新 prompt，清空 last_response_time
        write_state_file "$session_id" "start_time" "$current_time"
        write_state_file "$session_id" "prompt" "$prompt"
        write_state_file "$session_id" "last_response_time" ""
        write_state_file "$session_id" "notification_sent" "false"

        log_info "用户输入检测: session=$session_id, reset_time=$current_time"
        log_success "静默计时器已重置: session=$session_id"
    else
        # 状态文件不存在 - 这是新任务开始
        # 创建新的状态文件
        write_state_file "$session_id" "task_id" "$session_id"
        write_state_file "$session_id" "start_time" "$current_time"
        write_state_file "$session_id" "prompt" "$prompt"

        # 验证状态文件是否创建成功
        if [ -f "$state_file" ]; then
            log_info "任务开始: session=$session_id, start_time=$current_time"
        else
            log_error "创建状态文件失败: $state_file"
            exit 1
        fi
    fi
}

main "$@"
