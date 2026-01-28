#!/usr/bin/env bash
# scripts/notify.sh
# 通知分发器 - 根据配置将通知发送到不同渠道

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 发送通知到所有启用的渠道
# 参数1：任务描述
# 参数2：执行时长（秒）
# 参数3：完成时间戳
send_notifications() {
    local prompt="$1"
    local duration="$2"
    local timestamp="$3"

    # 读取配置
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        return 1
    fi

    # 检查全局开关
    if ! is_json_true "$CONFIG_FILE" "enabled"; then
        log_info "通知功能已禁用"
        return 0
    fi

    # 获取消息配置
    local include_prompt="false"
    local include_duration="false"
    local include_timestamp="false"

    if is_json_true "$CONFIG_FILE" "message.includePrompt"; then
        include_prompt="true"
    fi
    if is_json_true "$CONFIG_FILE" "message.includeDuration"; then
        include_duration="true"
    fi
    if is_json_true "$CONFIG_FILE" "message.includeTimestamp"; then
        include_timestamp="true"
    fi

    local max_prompt_length=$(get_json_value "$CONFIG_FILE" "message.maxPromptLength")
    max_prompt_length=${max_prompt_length:-100}

    # 构造消息内容
    local title="Claude Code 任务完成"
    local subtitle=""
    local message=""

    if [ "$include_duration" = "true" ]; then
        local duration_str=$(format_duration "$duration")
        subtitle="耗时 ${duration_str}"
    fi

    if [ "$include_prompt" = "true" ]; then
        local truncated_prompt=$(truncate_string "$prompt" "$max_prompt_length")
        message="${truncated_prompt}"
    fi

    if [ "$include_timestamp" = "true" ]; then
        if [ -n "$message" ]; then
            message="${message}\n\n完成时间: ${timestamp}"
        else
            message="完成时间: ${timestamp}"
        fi
    fi

    # 发送到各个渠道
    local channels_sent=""

    # Mac 系统通知
    if is_json_true "$CONFIG_FILE" "channels.mac.enabled"; then
        local sound="false"
        if is_json_true "$CONFIG_FILE" "channels.mac.sound"; then
            sound="true"
        fi

        if "$SCRIPT_DIR/notifiers/mac.sh" "$title" "$subtitle" "$message" "$sound"; then
            channels_sent="${channels_sent}mac "
        fi
    fi

    # 钉钉通知
    if is_json_true "$CONFIG_FILE" "channels.dingtalk.enabled"; then
        local webhook=$(get_json_value "$CONFIG_FILE" "channels.dingtalk.webhook")
        local secret=$(get_json_value "$CONFIG_FILE" "channels.dingtalk.secret")

        if [ -n "$webhook" ]; then
            # 构造 Markdown 内容
            local markdown_content="### 🎉 ${title}\n\n"
            if [ "$include_prompt" = "true" ]; then
                local truncated_prompt=$(truncate_string "$prompt" "$max_prompt_length")
                markdown_content="${markdown_content}**任务描述:** ${truncated_prompt}\n\n"
            fi
            if [ "$include_duration" = "true" ]; then
                local duration_str=$(format_duration "$duration")
                markdown_content="${markdown_content}**执行时长:** ${duration_str}\n\n"
            fi
            if [ "$include_timestamp" = "true" ]; then
                markdown_content="${markdown_content}**完成时间:** ${timestamp}"
            fi

            if "$SCRIPT_DIR/notifiers/dingtalk.sh" "$webhook" "$secret" "$title" "$markdown_content"; then
                channels_sent="${channels_sent}dingtalk "
            fi
        fi
    fi

    # 飞书通知
    if is_json_true "$CONFIG_FILE" "channels.lark.enabled"; then
        local webhook=$(get_json_value "$CONFIG_FILE" "channels.lark.webhook")

        if [ -n "$webhook" ]; then
            local text_content="${title}\n\n${message}"

            if "$SCRIPT_DIR/notifiers/lark.sh" "$webhook" "$title" "$text_content"; then
                channels_sent="${channels_sent}lark "
            fi
        fi
    fi

    # 记录日志
    if [ -n "$channels_sent" ]; then
        log_info "通知已发送到: $channels_sent"
    else
        log_warning "没有启用的通知渠道"
    fi
}

main() {
    local prompt="$1"
    local duration="$2"
    local timestamp="${3:-$(date '+%Y-%m-%d %H:%M:%S')}"

    send_notifications "$prompt" "$duration" "$timestamp"
}

main "$@"
