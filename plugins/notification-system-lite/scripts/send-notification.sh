#!/usr/bin/env bash
# scripts/send-notification.sh
# Notification(idle_prompt) hook - 发送空闲通知

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 错误处理函数 - 打印JSON格式错误到stdout
print_error() {
    local error_msg="$1"
    echo "{\"systemMessage\": \"notification-system-lite error: $error_msg\"}" >&1
}

# 发送通知
# 参数1：session_id
# 参数2：任务提示（prompt）
# 参数3：总时长（秒）
# 参数4：空闲时长（秒）
send_notification() {
    local session_id="$1"
    local prompt="$2"
    local total_duration="$3"
    local idle_duration="$4"

    # 配置文件路径
    local config_file="$CONFIG_FILE"

    # 检查配置文件
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        print_error "配置文件不存在: $config_file"
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
    local idle_duration_str=$(format_duration "$idle_duration")

    # 构建消息
    local title="Claude Code - 需要用户输入"
    local subtitle="任务已空闲 ${idle_duration_str}"
    local message="任务: ${truncated_prompt}\n总时长: ${total_duration_str}\n空闲时长: ${idle_duration_str}"

    # 发送 Mac 通知
    if is_json_true "$config_file" "channels.mac.enabled"; then
        local sound=$(get_json_value "$config_file" "channels.mac.sound")
        sound=${sound:-true}

        log_info "发送 Mac 通知: session_id=$session_id"
        if "${SCRIPT_DIR}/notifiers/mac.sh" "$title" "$subtitle" "$message" "$sound"; then
            log_success "Mac 通知发送成功: session_id=$session_id"
        else
            log_error "Mac 通知发送失败: session_id=$session_id"
        fi
    fi

    # 发送钉钉通知
    if is_json_true "$config_file" "channels.dingtalk.enabled"; then
        local webhook=$(get_json_value "$config_file" "channels.dingtalk.webhook")
        local secret=$(get_json_value "$config_file" "channels.dingtalk.secret")

        if [[ -n "$webhook" ]]; then
            log_info "发送钉钉通知: session_id=$session_id"
            # 钉钉使用 Markdown 格式
            local dingtalk_content="### ${title}\n\n**任务**: ${truncated_prompt}\n\n**总时长**: ${total_duration_str}\n\n**空闲时长**: ${idle_duration_str}"
            if "${SCRIPT_DIR}/notifiers/dingtalk.sh" "$webhook" "$secret" "$title" "$dingtalk_content"; then
                log_success "钉钉通知发送成功: session_id=$session_id"
            else
                log_error "钉钉通知发送失败: session_id=$session_id"
            fi
        fi
    fi

    # 发送飞书通知
    if is_json_true "$config_file" "channels.lark.enabled"; then
        local webhook=$(get_json_value "$config_file" "channels.lark.webhook")

        if [[ -n "$webhook" ]]; then
            log_info "发送飞书通知: session_id=$session_id"
            local lark_content="任务: ${truncated_prompt}\n总时长: ${total_duration_str}\n空闲时长: ${idle_duration_str}"
            if "${SCRIPT_DIR}/notifiers/lark.sh" "$webhook" "$title" "$lark_content"; then
                log_success "飞书通知发送成功: session_id=$session_id"
            else
                log_error "飞书通知发送失败: session_id=$session_id"
            fi
        fi
    fi
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
    local notification_type=$(echo "$payload" | jq -r '.notification_type // empty' 2>/dev/null || echo "")

    # 验证必需字段
    if [ -z "$session_id" ]; then
        log_error "payload 中缺少必需的 session_id 字段"
        print_error "payload 中缺少必需的 session_id 字段"
        exit 1
    fi

    if [ "$notification_type" != "idle_prompt" ]; then
        log_debug "忽略非 idle_prompt 通知: type=$notification_type"
        exit 0
    fi

    log_info "收到 idle_prompt 通知: session=$session_id"

    # 初始化目录（确保日志和状态目录存在）
    if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then
        print_error "无法创建日志目录"
        exit 1
    fi

    if ! init_state_dir; then
        print_error "无法初始化状态目录"
        exit 1
    fi

    # 检查状态文件是否存在
    if ! state_file_exists "$session_id"; then
        log_warning "状态文件不存在: session=$session_id，可能是新会话或状态已清理"
        exit 0
    fi

    # 读取状态信息
    local notification_sent=$(read_state_file "$session_id" "notification_sent")

    # 如果已发送通知，跳过
    if [[ "$notification_sent" == "true" ]]; then
        log_debug "会话 $session_id 已发送过通知，跳过"
        exit 0
    fi

    # 读取时间戳
    local start_time=$(read_state_file "$session_id" "start_time")
    local last_input_time=$(read_state_file "$session_id" "last_input_time")
    local prompt=$(read_state_file "$session_id" "prompt")

    # 验证必需字段
    if [[ -z "$start_time" ]] || [[ -z "$last_input_time" ]]; then
        log_error "会话 $session_id 缺少时间戳信息"
        print_error "会话 $session_id 缺少时间戳信息"
        exit 1
    fi

    if [[ -z "$prompt" ]]; then
        prompt="未知任务"
    fi

    # 获取当前时间
    local current_time=$(get_current_timestamp)

    # 计算时长
    local total_duration=$((current_time - start_time))
    local idle_duration=$((current_time - last_input_time))

    log_info "会话 $session_id: 总时长=${total_duration}秒, 空闲时长=${idle_duration}秒"

    # 发送通知
    if send_notification "$session_id" "$prompt" "$total_duration" "$idle_duration"; then
        # 更新状态：标记已发送通知
        write_state_file "$session_id" "notification_sent" "true"
        log_success "会话 $session_id 通知发送成功，已更新状态"
    else
        log_error "会话 $session_id 通知发送失败"
        print_error "会话 $session_id 通知发送失败"
        exit 1
    fi
}

main "$@"
