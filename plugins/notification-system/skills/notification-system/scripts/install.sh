#!/usr/bin/env bash
# scripts/install.sh
# Claude Code 通知系统安装脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 打印 hooks 配置示例
print_hooks_config() {
    echo ""
    echo "=========================================="
    echo "请手动添加以下配置到 ~/.claude/settings.json:"
    echo "=========================================="
    cat <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/system-notify/task-start.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/system-notify/task-complete.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF
    echo "=========================================="
}


main() {
    print_info "开始安装 Claude Code 通知系统..."

    # 获取脚本所在目录的绝对路径
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

    # 定义目标目录
    CLAUDE_DIR="$HOME/.claude"
    SYSTEM_NOTIFY_DIR="$CLAUDE_DIR/scripts/system-notify"
    NOTIFIERS_DIR="$SYSTEM_NOTIFY_DIR/notifiers"
    LOGS_DIR="$SYSTEM_NOTIFY_DIR/logs"
    TMP_DIR="$SYSTEM_NOTIFY_DIR/tmp"
    STATE_DIR="$SYSTEM_NOTIFY_DIR/state"

    # 创建目录结构
    print_info "创建目录结构..."
    if ! mkdir -p "$NOTIFIERS_DIR" "$LOGS_DIR" "$TMP_DIR" 2>/dev/null; then
        print_error "无法创建目录，请检查 $HOME/.claude 的写入权限"
        exit 1
    fi

    # 创建状态目录（包含敏感信息，需要严格权限）
    if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
        print_error "无法创建状态目录: $STATE_DIR"
        exit 1
    fi
    chmod 700 "$STATE_DIR"
    print_info "状态目录已创建: $STATE_DIR (权限: 700)"

    # 如果配置文件不存在，创建默认配置
    CONFIG_FILE="$SYSTEM_NOTIFY_DIR/notification-config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        print_info "创建默认配置文件..."

        # 检查源配置文件是否存在
        SOURCE_CONFIG="$PROJECT_DIR/notification-config.json"
        if [ ! -f "$SOURCE_CONFIG" ]; then
            print_error "源配置文件不存在: $SOURCE_CONFIG"
            print_error "请检查安装包完整性"
            exit 1
        fi

        # 复制配置文件
        if ! cp "$SOURCE_CONFIG" "$CONFIG_FILE"; then
            print_error "复制配置文件失败"
            exit 1
        fi

        chmod 600 "$CONFIG_FILE"
        print_info "配置文件已创建: $CONFIG_FILE"
    else
        print_warning "配置文件已存在，跳过创建"
    fi

    # 复制脚本文件
    print_info "复制脚本文件..."

    # 复制主脚本
    cp "$PROJECT_DIR/scripts/task-start.sh" "$SYSTEM_NOTIFY_DIR/"
    cp "$PROJECT_DIR/scripts/task-complete.sh" "$SYSTEM_NOTIFY_DIR/"
    cp "$PROJECT_DIR/scripts/task-monitor-daemon.sh" "$SYSTEM_NOTIFY_DIR/"
    cp "$PROJECT_DIR/scripts/utils.sh" "$SYSTEM_NOTIFY_DIR/"

    # 复制通知器脚本
    cp "$PROJECT_DIR/scripts/notifiers/mac.sh" "$NOTIFIERS_DIR/"
    cp "$PROJECT_DIR/scripts/notifiers/dingtalk.sh" "$NOTIFIERS_DIR/"
    cp "$PROJECT_DIR/scripts/notifiers/lark.sh" "$NOTIFIERS_DIR/"

    print_info "脚本文件已复制"

    # 设置执行权限
    print_info "设置脚本执行权限..."
    chmod +x "$SYSTEM_NOTIFY_DIR"/*.sh
    chmod +x "$NOTIFIERS_DIR"/*.sh
    print_info "权限设置完成"

    # 配置 hooks
    print_info "配置 Claude Code hooks..."
    SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    # 检查 jq 是否可用
    if ! command -v jq &> /dev/null; then
        print_warning "jq 未安装，无法自动配置 hooks"
        print_warning "请手动添加 hooks 配置到 ~/.claude/settings.json"
        print_hooks_config
        exit 0
    fi

    # 如果 settings.json 不存在，创建空配置
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
        print_info "已创建 settings.json 文件"
    fi

    # 备份原配置
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    print_info "已备份原配置到 $SETTINGS_FILE.backup"

    # 定义 hooks 配置
    local TASK_START_CMD="bash ~/.claude/scripts/system-notify/task-start.sh"
    local TASK_COMPLETE_CMD="bash ~/.claude/scripts/system-notify/task-complete.sh"

    # 使用 jq 合并 hooks 配置
    local temp_file=$(mktemp)
    jq --arg start_cmd "$TASK_START_CMD" \
       --arg complete_cmd "$TASK_COMPLETE_CMD" '
    # 确保 hooks 字段存在
    .hooks //= {} |

    # 配置 UserPromptSubmit hook
    .hooks.UserPromptSubmit //= [] |
    .hooks.UserPromptSubmit |=
        if any(.[].hooks[]?; .command == $start_cmd) then
            .
        else
            . + [{
                "hooks": [{
                    "type": "command",
                    "command": $start_cmd,
                    "timeout": 5
                }]
            }]
        end |

    # 配置 Stop hook
    .hooks.Stop //= [] |
    .hooks.Stop |=
        if any(.[].hooks[]?; .command == $complete_cmd) then
            .
        else
            . + [{
                "hooks": [{
                    "type": "command",
                    "command": $complete_cmd,
                    "timeout": 10
                }]
            }]
        end
    ' "$SETTINGS_FILE" > "$temp_file"

    # 验证生成的 JSON 是否有效
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$SETTINGS_FILE"
        print_info "✓ Hooks 配置已添加到 $SETTINGS_FILE"
    else
        print_error "生成的配置 JSON 无效，已回滚"
        mv "$SETTINGS_FILE.backup" "$SETTINGS_FILE"
        rm -f "$temp_file"
        exit 1
    fi

    # 打印后续说明
    print_info "安装成功！"
    echo ""
    echo "=========================================="
    echo "后续步骤："
    echo "=========================================="
    echo ""
    echo "1. 编辑配置文件（可选）："
    echo "   vi ~/.claude/scripts/system-notify/notification-config.json"
    echo ""
    echo "2. 注册的 Hooks："
    echo "   - UserPromptSubmit: 记录任务开始或重置静默计时器"
    echo "   - Stop: 任务完成时更新状态并启动监控守护进程"
    echo ""
    echo "3. 功能说明："
    echo "   - UserPromptSubmit hook 同时处理任务开始和用户后续输入"
    echo "   - 新任务时创建状态文件，后续输入时重置静默计时器"
    echo "   - 当任务静默时间超过阈值(默认15秒)，会自动发送通知"
    echo "   - 守护进程会在后台监控任务状态"
    echo "   - 状态文件位置: ~/.claude/scripts/system-notify/state/"
    echo ""
    echo "=========================================="
}

main "$@"
