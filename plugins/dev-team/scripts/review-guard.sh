#!/bin/bash
# review-guard.sh — Git pre-commit hook
# 检查 commit message 是否包含 [reviewed] 标记
# 由 dev-team 插件的 /dev-init 安装到 .git/hooks/pre-commit

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 检查是否有 staged changes
STAGED_FILES=$(git diff --cached --name-only)
if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

# 检查环境变量跳过标记（用于 CI/CD 或紧急情况）
if [ "$SKIP_REVIEW_GUARD" = "1" ]; then
    echo -e "${YELLOW}⚠️  review-guard: 已通过环境变量跳过 review 检查${NC}"
    exit 0
fi

# 检查最近的 code-reviewer 审查结果
# 查找项目中是否存在 [reviewed] 标记文件
REVIEW_MARKER=".claude/review-passed"

if [ -f "$REVIEW_MARKER" ]; then
    # 检查标记文件是否是最近创建的（1小时内）
    if [ "$(uname)" = "Darwin" ]; then
        # macOS
        MARKER_AGE=$(( $(date +%s) - $(stat -f %m "$REVIEW_MARKER") ))
    else
        # Linux
        MARKER_AGE=$(( $(date +%s) - $(stat -c %Y "$REVIEW_MARKER") ))
    fi

    if [ "$MARKER_AGE" -lt 3600 ]; then
        echo -e "${GREEN}✅ review-guard: 检测到有效的 review 通过标记${NC}"
        # 提交后删除标记，确保下次提交需要重新 review
        rm -f "$REVIEW_MARKER"
        exit 0
    else
        echo -e "${YELLOW}⚠️  review-guard: review 标记已过期（超过1小时）${NC}"
        rm -f "$REVIEW_MARKER"
    fi
fi

# 没有有效的 review 标记
echo -e "${RED}❌ review-guard: 代码尚未通过 Code Review！${NC}"
echo ""
echo -e "${YELLOW}请先运行 /code-reviewer 进行代码审查。${NC}"
echo -e "${YELLOW}审查通过后，/code-reviewer 会自动创建 review 通过标记。${NC}"
echo ""
echo -e "如需紧急跳过（不推荐）：${NC}"
echo -e "  ${YELLOW}SKIP_REVIEW_GUARD=1 git commit ...${NC}"
echo ""

exit 1
