#!/usr/bin/env bash
# scripts/notifiers/mac.sh
# Mac 系统通知实现

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 发送 Mac 系统通知
# 参数1：标题
# 参数2：副标题
# 参数3：消息内容
# 参数4：是否播放声音 (true/false)
send_mac_notification() {
    local title="$1"
    local subtitle="$2"
    local message="$3"
    local sound="$4"

    # 检查是否有 terminal-notifier
    if command -v terminal-notifier &> /dev/null; then
        log_info "使用 terminal-notifier 发送通知"

        local cmd=(terminal-notifier
            -title "$title"
            -subtitle "$subtitle"
            -message "$message"
        )

        if [ "$sound" = "true" ]; then
            cmd+=(-sound default)
        fi

        if "${cmd[@]}" &> /dev/null; then
            log_success "Mac 通知发送成功 (terminal-notifier)"
            return 0
        else
            log_error "terminal-notifier 发送失败，尝试降级"
        fi
    fi

    # 降级到 osascript
    log_info "使用 osascript 发送通知"

    local sound_option=""
    if [ "$sound" = "true" ]; then
        sound_option="sound name \"default\""
    fi

    local applescript="display notification \"$message\" with title \"$title\" subtitle \"$subtitle\" $sound_option"

    if osascript -e "$applescript" &> /dev/null; then
        log_success "Mac 通知发送成功 (osascript)"
        return 0
    else
        log_error "osascript 发送失败"
        return 1
    fi
}

# 主函数
main() {
    # 从命令行参数读取
    local title="$1"
    local subtitle="$2"
    local message="$3"
    local sound="${4:-true}"

    send_mac_notification "$title" "$subtitle" "$message" "$sound"
}

main "$@"
