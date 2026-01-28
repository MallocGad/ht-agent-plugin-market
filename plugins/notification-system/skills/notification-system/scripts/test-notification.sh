#!/usr/bin/env bash
# scripts/test-notification.sh
# 测试通知功能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

main() {
    print_header "Claude Code 通知系统测试"

    # 检查配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "错误：配置文件不存在: $CONFIG_FILE"
        echo "请先运行安装脚本: scripts/install.sh"
        exit 1
    fi

    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo ""

    # 测试通知
    print_header "发送测试通知"

    local test_prompt="这是一条测试通知消息"
    local test_duration=120  # 2分钟
    local test_timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "任务描述: $test_prompt"
    echo "执行时长: $test_duration 秒"
    echo "完成时间: $test_timestamp"
    echo ""

    # 调用通知脚本
    if "$SCRIPT_DIR/notify.sh" "$test_prompt" "$test_duration" "$test_timestamp"; then
        echo ""
        print_header "测试完成"
        echo "请检查是否收到通知"
        echo ""
        echo "如果没有收到通知，请检查："
        echo "1. 配置文件中是否启用了相应渠道"
        echo "2. Mac 通知：系统通知设置是否允许终端通知"
        echo "3. IM 通知：webhook 地址是否正确"
        echo "4. 日志文件：$LOG_FILE"
    else
        echo ""
        echo "测试失败，请检查日志: $LOG_FILE"
        exit 1
    fi
}

main "$@"
