#!/usr/bin/env bash
# scripts/task-complete.sh
# Stop hook - 从 hook payload 读取信息，更新状态，并触发守护进程

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

    # 提取关键信息
    local session_id=$(echo "$payload" | jq -r '.session_id // empty' 2>/dev/null || echo "")
    local hook_event_name=$(echo "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null || echo "")

    # session_id 为必需字段
    if [ -z "$session_id" ]; then
        log_error "payload 中缺少必需的 session_id 字段"
        exit 1
    fi

    # 初始化状态目录
    init_state_dir

    # 获取当前时间戳
    local response_time=$(get_current_timestamp)

    # 验证 response_time 是否成功生成
    if [ -z "$response_time" ]; then
        log_error "生成响应时间戳失败"
        exit 1
    fi

    # 更新状态文件：记录任务完成时间和响应时间
    write_state_file "$session_id" "last_response_time" "$response_time"
    write_state_file "$session_id" "notification_sent" "false"

    log_info "任务完成: session=$session_id, event=$hook_event_name, response_time=$response_time"

    # 检查守护进程是否运行
    if is_daemon_running; then
        log_debug "守护进程已在运行"
    else
        log_info "守护进程未运行，正在启动..."
        # 启动守护进程
        if start_daemon "$SCRIPT_DIR"; then
            log_success "守护进程启动成功"
        else
            log_error "守护进程启动失败"
            exit 1
        fi
    fi

    log_success "任务完成处理成功: session=$session_id"
}

main "$@"
