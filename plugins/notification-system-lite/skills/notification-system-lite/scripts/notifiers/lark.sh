#!/usr/bin/env bash
# scripts/notifiers/lark.sh
# 飞书机器人通知实现

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 发送飞书通知
# 参数1：webhook URL
# 参数2：标题
# 参数3：内容（支持多行，用 \n 分隔）
send_lark_notification() {
    local webhook="$1"
    local title="$2"
    local content="$3"

    # 检查 webhook 是否为空
    if [ -z "$webhook" ]; then
        log_error "飞书 webhook 为空"
        return 1
    fi

    # 使用简单的 text 格式
    local payload=""
    if command -v jq &> /dev/null; then
        # 使用 jq 安全构造 JSON
        local message_text="${title}\n\n${content}"
        payload=$(jq -n \
            --arg msg_type "text" \
            --arg text "$message_text" \
            '{msg_type: $msg_type, content: {text: $text}}')
    else
        # 手动转义特殊字符
        local escaped_title=$(echo "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local escaped_content=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g')
        payload=$(cat <<EOF
{
  "msg_type": "text",
  "content": {
    "text": "${escaped_title}\\n\\n${escaped_content}"
  }
}
EOF
)
    fi

    # 发送请求
    local response=$(curl -s -w "\n%{http_code}" -X POST "$webhook" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>&1)

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        log_success "飞书通知发送成功"
        return 0
    else
        log_error "飞书通知发送失败: HTTP $http_code, Response: $body"
        return 1
    fi
}

main() {
    local webhook="$1"
    local title="$2"
    local content="$3"

    send_lark_notification "$webhook" "$title" "$content"
}

main "$@"
