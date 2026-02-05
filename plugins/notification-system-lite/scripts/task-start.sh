#!/usr/bin/env bash
# scripts/task-start.sh
# UserPromptSubmit hook - 记录任务开始或更新用户输入

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 错误处理函数 - 打印JSON格式错误到stdout
print_error() {
    local error_msg="$1"
    echo "{\"systemMessage\": \"notification-system-lite error: $error_msg\"}" >&1
}

main() {
    # 从 stdin 读取 JSON payload
    local payload=$(cat)

    if [ -z "$payload" ]; then
        log_error "未收到 payload 数据"
        print_error "未收到 payload 数据"
        exit 1
    fi

    # 检查 jq 是否可用
    if ! command -v jq &> /dev/null; then
        log_error "jq 未安装，无法解析 JSON payload"
        print_error "jq 未安装，无法解析 JSON payload"
        exit 1
    fi

    # 提取关键信息
    local session_id=$(echo "$payload" | jq -r '.session_id // empty' 2>/dev/null || echo "")
    local hook_event_name=$(echo "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null || echo "")

    # session_id 为必需字段
    if [ -z "$session_id" ]; then
        log_error "payload 中缺少必需的 session_id 字段"
        print_error "payload 中缺少必需的 session_id 字段"
        exit 1
    fi

    # 初始化目录（确保日志和状态目录存在）
    if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then
        print_error "无法创建日志目录"
        exit 1
    fi

    if ! init_state_dir; then
        print_error "无法初始化状态目录"
        exit 1
    fi

    # 获取当前时间戳
    local current_time=$(get_current_timestamp)

    # 验证时间戳是否成功生成
    if [ -z "$current_time" ]; then
        log_error "生成时间戳失败"
        print_error "生成时间戳失败"
        exit 1
    fi

    # 提取用户输入的 prompt
    # 从 payload 中提取（如果有的话）
    local prompt=$(echo "$payload" | jq -r '.prompt // empty' 2>/dev/null || echo "")

    # 如果 payload 中没有 prompt，尝试从 transcript 中提取最后一条用户消息
    if [ -z "$prompt" ]; then
        local transcript_path=$(echo "$payload" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
        if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
            # 提取最后一条 role=user 的消息
            prompt=$(tail -20 "$transcript_path" | grep '"role":"user"' | tail -1 | jq -r '.content // empty' 2>/dev/null || echo "")
        fi
    fi

    # 如果还是没有 prompt，使用默认值
    if [ -z "$prompt" ]; then
        prompt="用户输入"
    fi

    # 检查状态文件是否存在
    if state_file_exists "$session_id"; then
        # 后续输入：更新状态
        log_info "更新任务状态: session=$session_id"

        # 更新 last_input_time, prompt, notification_sent
        write_state_file "$session_id" "last_input_time" "$current_time"
        write_state_file "$session_id" "prompt" "$prompt"
        write_state_file "$session_id" "notification_sent" "false"

        log_success "任务状态已更新: session=$session_id"
    else
        # 新任务：创建状态文件
        log_info "创建新任务状态: session=$session_id"

        # 创建状态文件
        write_state_file "$session_id" "session_id" "$session_id"
        write_state_file "$session_id" "start_time" "$current_time"
        write_state_file "$session_id" "last_input_time" "$current_time"
        write_state_file "$session_id" "prompt" "$prompt"
        write_state_file "$session_id" "notification_sent" "false"

        log_success "新任务状态已创建: session=$session_id"
    fi

    # 清理旧状态文件
    cleanup_old_state_files
}

main "$@"
