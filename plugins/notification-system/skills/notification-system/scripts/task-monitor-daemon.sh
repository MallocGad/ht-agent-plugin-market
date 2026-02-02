#!/usr/bin/env bash
# scripts/task-monitor-daemon.sh
# Background daemon that monitors task state files and sends notifications
# when users are silent for too long

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 配置
CHECK_INTERVAL=15  # 检查间隔（秒）
INACTIVITY_TIMEOUT=3600  # 无活动任务自动退出时间（1小时）

# 获取所有状态文件
# 返回：状态文件路径列表（每行一个）
get_state_files() {
    find "$STATE_DIR" -name "*.state" -type f 2>/dev/null || true
}

# 加载通知配置
# 返回：silence_threshold（秒）
load_notification_config() {
    local config_file="$CONFIG_FILE"

    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        echo "15"  # 默认15秒
        return 1
    fi

    local threshold=$(get_json_value "$config_file" "timeThreshold")
    if [[ -z "$threshold" ]]; then
        log_warning "无法读取 timeThreshold，使用默认值 15 秒"
        echo "15"
    else
        echo "$threshold"
    fi
}

# 发送通知
# 参数1：任务ID
# 参数2：任务提示（prompt）
# 参数3：总时长（秒）
# 参数4：静默时长（秒）
send_notification() {
    local task_id="$1"
    local prompt="$2"
    local total_duration="$3"
    local silence_duration="$4"

    # 配置文件路径
    local config_file="$CONFIG_FILE"

    # 检查配置文件
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi

    # 检查是否启用
    if ! is_json_true "$config_file" "enabled"; then
        log_info "通知系统已禁用，跳过发送"
        return 0
    fi

    # 获取配置
    local max_prompt_length=$(get_json_value "$config_file" "message.maxPromptLength")
    max_prompt_length=${max_prompt_length:-50}

    # 截断 prompt
    local truncated_prompt=$(truncate_string "$prompt" "$max_prompt_length")

    # 格式化时长
    local total_duration_str=$(format_duration "$total_duration")
    local silence_duration_str=$(format_duration "$silence_duration")

    # 构建消息
    local title="Claude Code - 需要用户输入"
    local subtitle="任务已静默 ${silence_duration_str}"
    local message="任务: ${truncated_prompt}\n总时长: ${total_duration_str}\n静默时长: ${silence_duration_str}"

    # 发送 Mac 通知
    if is_json_true "$config_file" "channels.mac.enabled"; then
        local sound=$(get_json_value "$config_file" "channels.mac.sound")
        sound=${sound:-true}

        log_info "发送 Mac 通知: task_id=$task_id"
        if "${SCRIPT_DIR}/notifiers/mac.sh" "$title" "$subtitle" "$message" "$sound"; then
            log_success "Mac 通知发送成功: task_id=$task_id"
        else
            log_error "Mac 通知发送失败: task_id=$task_id"
        fi
    fi

    # 发送钉钉通知
    if is_json_true "$config_file" "channels.dingtalk.enabled"; then
        local webhook=$(get_json_value "$config_file" "channels.dingtalk.webhook")
        local secret=$(get_json_value "$config_file" "channels.dingtalk.secret")

        if [[ -n "$webhook" ]]; then
            log_info "发送钉钉通知: task_id=$task_id"
            if "${SCRIPT_DIR}/notifiers/dingtalk.sh" "$webhook" "$secret" "$title" "$message"; then
                log_success "钉钉通知发送成功: task_id=$task_id"
            else
                log_error "钉钉通知发送失败: task_id=$task_id"
            fi
        fi
    fi

    # 发送飞书通知
    if is_json_true "$config_file" "channels.lark.enabled"; then
        local webhook=$(get_json_value "$config_file" "channels.lark.webhook")

        if [[ -n "$webhook" ]]; then
            log_info "发送飞书通知: task_id=$task_id"
            if "${SCRIPT_DIR}/notifiers/lark.sh" "$title" "$message" "$webhook"; then
                log_success "飞书通知发送成功: task_id=$task_id"
            else
                log_error "飞书通知发送失败: task_id=$task_id"
            fi
        fi
    fi
}

# 检查单个任务状态并发送通知（如果需要）
# 参数1：状态文件路径
# 参数2：静默阈值（秒）
check_task_state() {
    local state_file="$1"
    local silence_threshold="$2"

    # 提取任务ID（从文件名）
    local task_id=$(basename "$state_file" .state)

    # 读取状态信息
    local notification_sent=$(jq -r '.notification_sent // "false"' "$state_file" 2>/dev/null || echo "false")

    # 如果已发送通知，跳过
    if [[ "$notification_sent" == "true" ]]; then
        log_debug "任务 $task_id 已发送过通知，跳过"
        return 0
    fi

    # 读取时间戳
    local start_time=$(jq -r '.start_time // ""' "$state_file" 2>/dev/null || echo "")
    local last_response_time=$(jq -r '.last_response_time // ""' "$state_file" 2>/dev/null || echo "")

    # 验证必需字段
    if [[ -z "$start_time" ]] || [[ -z "$last_response_time" ]]; then
        log_debug "任务 $task_id 缺少时间戳信息，跳过"
        return 0
    fi

    # 获取当前时间
    local current_time=$(get_current_timestamp)

    # 计算静默时长
    local silence_duration=$((current_time - last_response_time))

    # 检查是否超过阈值
    if [[ $silence_duration -ge $silence_threshold ]]; then
        log_info "任务 $task_id 已静默 ${silence_duration} 秒，超过阈值 ${silence_threshold} 秒"

        # 读取 prompt
        local prompt=$(jq -r '.prompt // "未知任务"' "$state_file" 2>/dev/null || echo "未知任务")

        # 计算总时长
        local total_duration=$((current_time - start_time))

        # 发送通知
        if send_notification "$task_id" "$prompt" "$total_duration" "$silence_duration"; then
            # 更新状态：标记已发送通知
            local tmp_file="${state_file}.tmp"
            if jq '.notification_sent = true' "$state_file" > "$tmp_file" 2>/dev/null; then
                mv "$tmp_file" "$state_file"
                log_success "任务 $task_id 通知发送成功，已更新状态"
            else
                log_error "Failed to update state file: $state_file"
                rm -f "$tmp_file"
                return 1
            fi
        else
            log_error "任务 $task_id 通知发送失败"
        fi
    else
        log_debug "任务 $task_id 静默时长 ${silence_duration} 秒，未达到阈值 ${silence_threshold} 秒"
    fi
}

# 清理函数
cleanup() {
    log_info "守护进程收到退出信号，正在清理..."
    rm -f "$DAEMON_PID_FILE"
    log_info "守护进程已退出"
    exit 0
}

# 主守护进程循环
main() {
    # 初始化状态目录
    init_state_dir

    log_info "守护进程启动: PID=$$"

    # 设置信号处理
    trap cleanup SIGTERM SIGINT SIGQUIT SIGHUP EXIT

    # 加载配置
    local silence_threshold=$(load_notification_config)
    log_info "静默阈值: ${silence_threshold} 秒"

    # 跟踪无活动时间
    local last_active_time=$(get_current_timestamp)

    # 错误计数器
    local error_count=0
    local max_errors=10

    # 主循环
    while true; do
        # 获取所有状态文件
        local state_files=$(get_state_files)

        if [[ -z "$state_files" ]]; then
            # 没有活动任务
            local current_time=$(get_current_timestamp)
            local inactive_duration=$((current_time - last_active_time))

            log_debug "无活动任务，已持续 ${inactive_duration} 秒"

            # 检查是否超过不活动超时
            if [[ $inactive_duration -ge $INACTIVITY_TIMEOUT ]]; then
                log_info "无活动任务已超过 ${INACTIVITY_TIMEOUT} 秒，守护进程自动退出"
                cleanup
            fi
        else
            # 有活动任务，重置不活动计时器
            last_active_time=$(get_current_timestamp)

            # 检查每个任务
            while IFS= read -r state_file; do
                if [[ -f "$state_file" ]]; then
                    if ! check_task_state "$state_file" "$silence_threshold"; then
                        error_count=$((error_count + 1))
                        log_error "Failed to check task state: $state_file (error count: $error_count)"

                        if [[ $error_count -ge $max_errors ]]; then
                            log_error "Too many errors ($error_count), exiting daemon"
                            cleanup
                        fi
                    else
                        # Reset error count on success
                        error_count=0
                    fi
                fi
            done <<< "$state_files"
        fi

        # 清理旧状态文件（24小时前的）
        if ! cleanup_old_state_files; then
            log_warning "Failed to cleanup old state files"
        fi

        # 等待下一次检查
        sleep "$CHECK_INTERVAL"
    done
}

# 启动主函数
main "$@"
