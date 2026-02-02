#!/usr/bin/env bash
# scripts/notifiers/dingtalk.sh
# 钉钉机器人通知实现

set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 计算钉钉加签
# 参数1：secret
# 返回：带 timestamp 和 sign 的 URL 参数
generate_dingtalk_sign() {
    local secret="$1"

    if [ -z "$secret" ]; then
        echo ""
        return
    fi

    # 获取当前时间戳（毫秒）
    local timestamp=$(date +%s%3N)

    # 计算签名
    local string_to_sign="${timestamp}\n${secret}"
    local sign=$(echo -ne "$string_to_sign" | openssl dgst -sha256 -hmac "$secret" -binary | base64)

    # URL 编码
    local encoded_sign=""
    if command -v jq &> /dev/null; then
        encoded_sign=$(echo -n "$sign" | jq -sRr @uri)
    elif command -v python3 &> /dev/null; then
        encoded_sign=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$sign'''))")
    else
        # 简单的 URL 编码（仅处理常见字符）
        encoded_sign=$(echo -n "$sign" | sed 's/ /%20/g; s/+/%2B/g; s/\//%2F/g; s/=/%3D/g')
    fi

    echo "&timestamp=${timestamp}&sign=${encoded_sign}"
}

# 发送钉钉通知
# 参数1：webhook URL
# 参数2：secret（可选）
# 参数3：标题
# 参数4：消息内容（Markdown）
send_dingtalk_notification() {
    local webhook="$1"
    local secret="$2"
    local title="$3"
    local content="$4"

    # 检查 webhook 是否为空
    if [ -z "$webhook" ]; then
        log_error "钉钉 webhook 为空"
        return 1
    fi

    # 生成加签（如果有 secret）
    local sign_params=$(generate_dingtalk_sign "$secret")
    local full_url="${webhook}${sign_params}"

    # 构造 JSON payload
    local payload=""
    if command -v jq &> /dev/null; then
        # 使用 jq 安全构造 JSON
        payload=$(jq -n \
            --arg msgtype "markdown" \
            --arg title "$title" \
            --arg text "$content" \
            '{msgtype: $msgtype, markdown: {title: $title, text: $text}}')
    else
        # 手动转义特殊字符
        local escaped_title=$(echo "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local escaped_content=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g')
        payload=$(cat <<EOF
{
  "msgtype": "markdown",
  "markdown": {
    "title": "$escaped_title",
    "text": "$escaped_content"
  }
}
EOF
)
    fi

    # 发送请求
    local response=$(curl -s -w "\n%{http_code}" -X POST "$full_url" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>&1)

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        log_success "钉钉通知发送成功"
        return 0
    else
        log_error "钉钉通知发送失败: HTTP $http_code, Response: $body"
        return 1
    fi
}

main() {
    local webhook="$1"
    local secret="${2:-}"
    local title="$3"
    local content="$4"

    send_dingtalk_notification "$webhook" "$secret" "$title" "$content"
}

main "$@"
