#!/usr/bin/env bash
# scripts/task-complete.sh
# Stop hook - 计算耗时并发送通知

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

    # 读取状态文件
    local state_file="/tmp/claude-task-${session_id}.json"

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

    log_info "任务完成: session=$session_id, duration=${duration}s"

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

    # 发送通知
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    "$SCRIPT_DIR/notify.sh" "$prompt" "$duration" "$timestamp"

    # 清理状态文件
    rm -f "$state_file"

    log_info "通知流程完成"
}

main "$@"
