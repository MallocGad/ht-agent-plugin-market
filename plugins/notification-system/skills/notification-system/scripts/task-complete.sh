#!/usr/bin/env bash
# scripts/task-complete.sh
# Stop hook - 从 hook payload 读取信息并发送通知

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main() {
    # 从 stdin 读取 JSON payload
    local input=$(cat)

    if [ -z "$input" ]; then
        log_error "未收到 hook payload 数据"
        exit 0
    fi

    # 提取关键信息
    local session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || echo "")
    local transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
    local cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null || echo "")
    local hook_event_name=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || echo "Stop")

    # 如果 session_id 为空，使用默认值
    if [ -z "$session_id" ]; then
        session_id="${CLAUDE_SESSION_ID:-default}"
        log_warning "hook payload 中无 session_id，使用环境变量或默认值: $session_id"
    fi

    # 读取状态文件获取任务开始时间和提示
    local state_file="$TMP_DIR/claude-task-${session_id}.json"

    if [ ! -f "$state_file" ]; then
        log_info "状态文件不存在，跳过通知: $state_file"
        exit 0
    fi

    # 读取开始时间和提示
    local start_time=$(get_json_value "$state_file" "startTime")
    local prompt=$(get_json_value "$state_file" "prompt")

    if [ -z "$start_time" ]; then
        log_error "无法从状态文件读取开始时间"
        rm -f "$state_file"
        exit 0
    fi

    # 计算耗时
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "任务完成: session=$session_id, duration=${duration}s, event=$hook_event_name"

    # 读取时间阈值
    local threshold=$(get_json_value "$CONFIG_FILE" "timeThreshold")
    threshold=${threshold:-15}

    # 判断是否超过阈值
    if [ "$duration" -lt "$threshold" ]; then
        log_info "任务耗时 ${duration}s，未超过阈值 ${threshold}s，跳过通知"
        rm -f "$state_file"
        exit 0
    fi

    log_info "任务耗时 ${duration}s，超过阈值 ${threshold}s，准备发送通知"

    # 使用状态文件中读取的 prompt 作为通知摘要
    local notification_text="$prompt"

    # 发送通知
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    "$SCRIPT_DIR/notify.sh" "$notification_text" "$duration" "$timestamp"

    # 清理状态文件
    rm -f "$state_file"

    log_info "通知流程完成"
}

main "$@"
