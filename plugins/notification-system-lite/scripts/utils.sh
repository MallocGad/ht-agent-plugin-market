#!/usr/bin/env bash
# scripts/utils.sh
# 通用工具函数库

# 获取插件目录
if [ -n "$PLUGIN_DIR" ]; then
    # 从环境变量获取（hook 执行时）
    NOTIFICATION_LITE_DIR="$PLUGIN_DIR"
else
    # 从脚本路径推断（直接执行时）
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    NOTIFICATION_LITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# 配置文件和日志路径（都在插件目录下）
CONFIG_FILE="$NOTIFICATION_LITE_DIR/notification-config.json"
LOG_DIR="$NOTIFICATION_LITE_DIR/logs"
LOG_FILE="$LOG_DIR/notification.log"
STATE_DIR="$NOTIFICATION_LITE_DIR/state"

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

log_debug() {
    local message="$1"
    local log_dir="$(dirname "$LOG_FILE")"

    # 确保日志目录存在
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $message" >> "$LOG_FILE" 2>/dev/null
}

# 将秒数格式化为人类可读的时长（中文版本，用于通知显示）
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

# ============================================================
# State Management
# ============================================================

# 初始化状态目录
init_state_dir() {
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"  # Secure - contains user prompts
}

# 清理30分钟前的旧状态文件
cleanup_old_state_files() {
    # Remove state files older than 30 minutes
    find "$STATE_DIR" -name "*.state" -mmin +30 -delete 2>/dev/null || true
}

# 写入状态文件的键值对
# 参数1：session_id
# 参数2：键名
# 参数3：值
write_state_file() {
    local session_id="$1"
    local key="$2"
    local value="$3"
    local state_file="${STATE_DIR}/${session_id}.state"

    # Create state file if doesn't exist
    if [[ ! -f "$state_file" ]]; then
        echo '{}' > "$state_file"
    fi

    # Update key-value using jq (handle both string and number values)
    local tmp_file="${state_file}.tmp"
    if [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
        # Numeric or boolean value
        jq --arg key "$key" --argjson val "$value" '.[$key] = $val' "$state_file" > "$tmp_file"
    else
        # String value
        jq --arg key "$key" --arg val "$value" '.[$key] = $val' "$state_file" > "$tmp_file"
    fi
    mv "$tmp_file" "$state_file"
}

# 读取状态文件的键值
# 参数1：session_id
# 参数2：键名
# 返回：值；失败时返回空
read_state_file() {
    local session_id="$1"
    local key="$2"
    local state_file="${STATE_DIR}/${session_id}.state"

    if [[ ! -f "$state_file" ]]; then
        echo ""
        return 1
    fi

    jq -r --arg key "$key" '.[$key] // ""' "$state_file"
}

# 获取状态文件路径
# 参数1：session_id
# 返回：状态文件的完整路径
get_state_file_path() {
    local session_id="$1"
    echo "${STATE_DIR}/${session_id}.state"
}

# 删除状态文件
# 参数1：session_id
delete_state_file() {
    local session_id="$1"
    rm -f "${STATE_DIR}/${session_id}.state"
}

# 检查状态文件是否存在
# 参数1：session_id
# 返回：0 (存在) 或 1 (不存在)
state_file_exists() {
    local session_id="$1"
    local state_file="${STATE_DIR}/${session_id}.state"
    [[ -f "$state_file" ]]
}

# ============================================================
# Time Calculation
# ============================================================

# 获取当前时间戳（秒）
get_current_timestamp() {
    date +%s
}

# 计算时长（秒）
# 参数1：开始时间戳
# 参数2：结束时间戳
# 返回：时长（秒）
calculate_duration() {
    local start="$1"
    local end="$2"
    echo $((end - start))
}
