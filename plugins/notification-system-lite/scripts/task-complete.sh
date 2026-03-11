#!/usr/bin/env bash
# scripts/task-complete.sh
# Stop hook - 记录 Claude 响应完成时间
#
# 目的：在 Claude 每次响应结束时更新 last_response_time，
# 使 send-notification.sh 能准确计算用户真正的空闲时长
# （而不是从"用户上次提交 prompt"算起，那样会把 Claude 处理时间也算进去）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main() {
    local payload=$(cat)

    # payload 为空时静默退出（不阻断主流程）
    if [ -z "$payload" ]; then exit 0; fi

    if ! command -v jq &> /dev/null; then exit 0; fi

    local session_id=$(echo "$payload" | jq -r '.session_id // empty' 2>/dev/null || echo "")

    if [ -z "$session_id" ]; then exit 0; fi

    # 确保目录存在
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    init_state_dir 2>/dev/null || true

    # 仅当状态文件存在时才更新（避免处理无效/过期会话）
    if ! state_file_exists "$session_id"; then
        exit 0
    fi

    local current_time=$(get_current_timestamp)
    write_state_file "$session_id" "last_response_time" "$current_time"

    log_info "已记录响应完成时间: session=$session_id, time=$current_time"
}

main "$@"
