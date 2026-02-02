#!/usr/bin/env bash
# scripts/stop-daemon.sh
# SessionEnd hook - 当 Claude Code 退出时停止守护进程

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main() {
    log_info "收到 SessionEnd 事件，正在停止守护进程..."

    if is_daemon_running; then
        stop_daemon
        log_success "守护进程已停止"
    else
        log_debug "守护进程未运行，无需停止"
    fi
}

main "$@"
