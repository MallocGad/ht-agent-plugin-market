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

main() {
    print_info "开始安装 Claude Code 通知系统..."

    # 获取脚本所在目录的绝对路径
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

    # 定义目标目录
    CLAUDE_DIR="$HOME/.claude"
    SCRIPTS_DIR="$CLAUDE_DIR/scripts"
    LOGS_DIR="$CLAUDE_DIR/logs"

    # 创建目录结构
    print_info "创建目录结构..."
    if ! mkdir -p "$SCRIPTS_DIR/notifiers" "$LOGS_DIR" 2>/dev/null; then
        print_error "无法创建目录，请检查 $HOME/.claude 的写入权限"
        exit 1
    fi

    # 如果配置文件不存在，创建默认配置
    CONFIG_FILE="$CLAUDE_DIR/notification-config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        print_info "创建默认配置文件..."

        # 检查源配置文件是否存在
        SOURCE_CONFIG="$PROJECT_DIR/config/notification-config.json"
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

    # 获取当前脚本所在的项目目录
    NOTIFIERS_DIR="$SCRIPTS_DIR/notifiers"

    # 复制主脚本
    cp "$PROJECT_DIR/scripts/task-start.sh" "$SCRIPTS_DIR/"
    cp "$PROJECT_DIR/scripts/task-complete.sh" "$SCRIPTS_DIR/"
    cp "$PROJECT_DIR/scripts/notify.sh" "$SCRIPTS_DIR/"
    cp "$PROJECT_DIR/scripts/utils.sh" "$SCRIPTS_DIR/"

    # 复制通知器脚本
    cp "$PROJECT_DIR/scripts/notifiers/mac.sh" "$NOTIFIERS_DIR/"
    cp "$PROJECT_DIR/scripts/notifiers/dingtalk.sh" "$NOTIFIERS_DIR/"
    cp "$PROJECT_DIR/scripts/notifiers/lark.sh" "$NOTIFIERS_DIR/"

    print_info "脚本文件已复制"

    # 设置执行权限
    print_info "设置脚本执行权限..."
    chmod +x "$SCRIPTS_DIR"/*.sh
    chmod +x "$NOTIFIERS_DIR"/*.sh
    print_info "权限设置完成"

    # 打印后续配置说明
    print_info "安装成功！"
    echo ""
    echo "=========================================="
    echo "后续配置步骤："
    echo "=========================================="
    echo ""
    echo "1. 编辑配置文件（可选）："
    echo "   vi ~/.claude/notification-config.json"
    echo ""
    echo "2. 配置 Claude Code hooks："
    echo "   在 ~/.claude/settings.json 中添加:"
    cat <<'EOF'
   {
     "UserPromptSubmit": [{
       "hooks": [{
         "type": "command",
         "command": "~/.claude/scripts/task-start.sh",
         "timeout": 5
       }]
     }],
     "Stop": [{
       "hooks": [{
         "type": "command",
         "command": "~/.claude/scripts/task-complete.sh",
         "timeout": 10
       }]
     }]
   }
EOF
    echo ""
    echo "3. 测试通知功能："
    echo "   ~/.claude/scripts/test-notification.sh"
    echo ""
    echo "=========================================="
}

main "$@"
