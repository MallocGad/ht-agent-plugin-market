#!/usr/bin/env bash
# scripts/utils.sh
# 通用工具函数库

# 配置文件和日志路径
CLAUDE_DIR="$HOME/.claude"
SYSTEM_NOTIFY_DIR="$CLAUDE_DIR/scripts/system-notify"
CONFIG_FILE="$CLAUDE_DIR/notification-config.json"
LOG_FILE="$SYSTEM_NOTIFY_DIR/logs/notification.log"
TMP_DIR="$SYSTEM_NOTIFY_DIR/tmp"

# 日志函数
log_info() {
    local message="$1"
    local log_dir="$(dirname "$LOG_FILE")"

    # 确保日志目录存在
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE" 2>/dev/null
}

log_error() {
    local message="$1"
    local log_dir="$(dirname "$LOG_FILE")"

    # 确保日志目录存在
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE" 2>/dev/null
}

log_success() {
    local message="$1"
    local log_dir="$(dirname "$LOG_FILE")"

    # 确保日志目录存在
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $message" >> "$LOG_FILE" 2>/dev/null
}

log_warning() {
    local message="$1"
    local log_dir="$(dirname "$LOG_FILE")"

    # 确保日志目录存在
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $message" >> "$LOG_FILE" 2>/dev/null
}

# 将秒数格式化为人类可读的时长
# 参数：秒数
# 返回：格式化的字符串（如 "2分15秒"）
format_duration() {
    local seconds="$1"

    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}秒"
    elif [ "$seconds" -lt 3600 ]; then
        local minutes=$((seconds / 60))
        local remaining_seconds=$((seconds % 60))
        if [ "$remaining_seconds" -eq 0 ]; then
            echo "${minutes}分钟"
        else
            echo "${minutes}分${remaining_seconds}秒"
        fi
    else
        local hours=$((seconds / 3600))
        local remaining_minutes=$(( (seconds % 3600) / 60 ))
        if [ "$remaining_minutes" -eq 0 ]; then
            echo "${hours}小时"
        else
            echo "${hours}小时${remaining_minutes}分钟"
        fi
    fi
}

# 从 JSON 中提取值
# 参数1：JSON 字符串或文件路径（文件路径必须在 ~/.claude 目录下）
# 参数2：键名（优先使用 jq 时支持嵌套键如 "channels.mac.enabled"，降级方案仅支持顶层简单键）
# 返回：值；失败时返回空并设置非零退出码
get_json_value() {
    local json_input="$1"
    local key="$2"
    local json_content

    # 检查输入是文件还是字符串
    if [ -f "$json_input" ]; then
        # 获取绝对路径（处理 realpath 不存在的情况）
        local real_path=""
        if command -v realpath &> /dev/null; then
            real_path=$(realpath "$json_input" 2>/dev/null)
        elif command -v readlink &> /dev/null; then
            real_path=$(readlink -f "$json_input" 2>/dev/null)
        else
            # 最终降级方案：使用 cd + pwd
            local dir=$(dirname "$json_input")
            local file=$(basename "$json_input")
            real_path="$(cd "$dir" 2>/dev/null && pwd)/$file"
        fi

        # 验证路径解析是否成功
        if [ -z "$real_path" ]; then
            log_error "无法解析文件路径: $json_input"
            return 1
        fi

        # 安全检查：只允许 ~/.claude 目录和 /tmp 目录（用于状态文件）
        if [[ ! "$real_path" =~ ^$HOME/\.claude/ ]] && [[ ! "$real_path" =~ ^/tmp/ ]] && [[ ! "$real_path" =~ ^/private/tmp/ ]]; then
            log_error "拒绝读取不安全的路径: $json_input"
            log_error "解析后的路径: $real_path"
            return 1
        fi

        # 读取文件
        json_content=$(cat "$real_path" 2>/dev/null) || {
            log_error "无法读取文件: $real_path"
            return 1
        }
    else
        json_content="$json_input"
    fi

    # 优先使用 jq
    if command -v jq &> /dev/null; then
        echo "$json_content" | jq -r ".$key // empty"
    else
        # 降级方案：使用 grep + sed（仅支持简单顶层键）
        if [[ "$key" == *.* ]]; then
            log_error "降级 JSON 解析不支持嵌套键: $key，请安装 jq"
            return 1
        fi
        echo "$json_content" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" | sed 's/.*:[[:space:]]*//' | tr -d '"'
    fi
}

# 检查 JSON 布尔值
# 参数1：JSON 文件路径
# 参数2：键名
# 返回：0 (true) 或 1 (false)
is_json_true() {
    local json_file="$1"
    local key="$2"

    local value=$(get_json_value "$json_file" "$key")

    if [ "$value" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# 截断字符串到指定长度
# 参数1：字符串
# 参数2：最大长度
# 返回：截断后的字符串（超过长度时添加 "..."）
# 注意：按字节截断，可能在多字节 UTF-8 字符中间截断
truncate_string() {
    local string="$1"
    local max_length="$2"

    if [ ${#string} -le "$max_length" ]; then
        echo "$string"
    else
        echo "${string:0:$max_length}..."
    fi
}
