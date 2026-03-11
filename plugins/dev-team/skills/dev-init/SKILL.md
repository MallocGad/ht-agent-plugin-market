---
name: dev-init
description: "开发团队初始化。收集项目技术栈、规范等信息，生成 project-profile.json 并替换各角色 skill 模板中的占位符。使用 /dev-init 初始化，/dev-init --reset 重新初始化。"
---

# Dev Init — 开发团队初始化

## 触发方式

- `/dev-init` — 首次初始化
- `/dev-init --reset` — 重新初始化（覆盖已有配置）

## 执行流程

### Step 1: 检查初始化状态

读取 `${CLAUDE_PLUGIN_ROOT}/project-profile.json`：
- 如果文件存在且 `initialized === true`，且没有 `--reset` 参数 → 提示已初始化，询问是否重新初始化
- 如果文件不存在或有 `--reset` 参数 → 进入 Step 2

### Step 2: 收集项目信息

使用 AskUserQuestion 工具，依次收集以下信息。每个问题提供合理的默认选项，用户可选择或自定义：

**Q1: 技术栈**
- 编程语言（如 Java, TypeScript, Python, Go）
- 框架（如 Spring Boot, Next.js, FastAPI, Gin）
- 构建工具（如 Maven, Gradle, npm, pnpm）
- 数据库（如 MySQL, PostgreSQL, MongoDB）
- ORM（如 MyBatis-Plus, Prisma, SQLAlchemy, GORM）
- 缓存（如 Redis, Caffeine, 无）

**Q2: 分层架构**
- 如：controller-service-mapper, controller-service-repository, routes-handlers-models
- 用户可自定义

**Q3: 命名规范**
- 包/模块命名（如 com.company.project）
- 类命名（如 PascalCase）
- 方法命名（如 camelCase / snake_case）
- 数据库表名（如 snake_case，前缀如 t_）
- 数据库字段名（如 snake_case）
- API 路径风格（如 /api/v1/kebab-case）

**Q4: Git 规范**
- 分支命名（如 feature/xxx, fix/xxx, hotfix/xxx）
- Commit 格式（如 Conventional Commits: feat: xxx, fix: xxx）

**Q5: API 规范**
- 响应格式（如 `{"code": 0, "message": "ok", "data": {...}}`）
- 错误处理方式（如统一异常处理 + 错误码枚举）

**Q6: 测试配置**
- 测试框架（如 JUnit5 + Mockito, Jest, Pytest）
- 覆盖率目标（如 80%）
- 测试类型（如 单元测试, 集成测试）

**Q7: Review 关注重点**
- 如：安全性, 性能, 可维护性, 代码规范, 异常处理

### Step 3: 保存配置

将收集到的信息写入 `${CLAUDE_PLUGIN_ROOT}/project-profile.json`，格式如下：

```json
{
  "initialized": true,
  "tech_stack": {
    "language": "用户输入",
    "framework": "用户输入",
    "build_tool": "用户输入",
    "database": "用户输入",
    "orm": "用户输入",
    "cache": "用户输入"
  },
  "architecture_layers": "用户输入",
  "naming_convention": {
    "package": "用户输入",
    "class": "用户输入",
    "method": "用户输入",
    "database_table": "用户输入",
    "database_column": "用户输入",
    "api_path": "用户输入"
  },
  "git_convention": {
    "branch_pattern": "用户输入",
    "commit_format": "用户输入"
  },
  "api_convention": {
    "response_format": "用户输入",
    "error_handling": "用户输入"
  },
  "test_config": {
    "framework": "用户输入",
    "coverage_target": "用户输入",
    "types": ["用户输入"]
  },
  "review_standards": {
    "priorities": ["用户输入"]
  }
}
```

### Step 4: 替换各 Skill 模板占位符

读取以下 6 个 SKILL.md 文件，将所有 `{{占位符}}` 替换为 project-profile.json 中的实际值，然后写回：

- `${CLAUDE_PLUGIN_ROOT}/skills/prd-analyst/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/solution-designer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/developer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/arch-reviewer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/code-reviewer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/test-engineer/SKILL.md`

**占位符对照表：**

| 占位符 | 来源 |
|--------|------|
| `{{LANGUAGE}}` | tech_stack.language |
| `{{FRAMEWORK}}` | tech_stack.framework |
| `{{BUILD_TOOL}}` | tech_stack.build_tool |
| `{{DATABASE}}` | tech_stack.database |
| `{{ORM}}` | tech_stack.orm |
| `{{CACHE}}` | tech_stack.cache |
| `{{ARCHITECTURE_LAYERS}}` | architecture_layers |
| `{{PACKAGE_NAMING}}` | naming_convention.package |
| `{{CLASS_NAMING}}` | naming_convention.class |
| `{{METHOD_NAMING}}` | naming_convention.method |
| `{{TABLE_NAMING}}` | naming_convention.database_table |
| `{{COLUMN_NAMING}}` | naming_convention.database_column |
| `{{API_PATH_STYLE}}` | naming_convention.api_path |
| `{{BRANCH_PATTERN}}` | git_convention.branch_pattern |
| `{{COMMIT_FORMAT}}` | git_convention.commit_format |
| `{{API_RESPONSE_FORMAT}}` | api_convention.response_format |
| `{{ERROR_HANDLING}}` | api_convention.error_handling |
| `{{TEST_FRAMEWORK}}` | test_config.framework |
| `{{COVERAGE_TARGET}}` | test_config.coverage_target |
| `{{TEST_TYPES}}` | test_config.types（逗号拼接） |
| `{{REVIEW_PRIORITIES}}` | review_standards.priorities（逗号拼接） |

使用 Read 工具读取每个 SKILL.md，用 Edit 工具逐个替换占位符，将 `{{XXX}}` 替换为对应值。

### Step 5: 安装 Git Pre-commit Hook

1. 检查当前工作目录是否是 Git 仓库（检查 `.git` 目录）
2. 如果是 → 将 `${CLAUDE_PLUGIN_ROOT}/scripts/review-guard.sh` 复制到 `.git/hooks/pre-commit`
3. 添加执行权限 `chmod +x .git/hooks/pre-commit`
4. 如果已存在 pre-commit hook → 提示用户是否覆盖

### Step 6: 输出初始化结果

输出初始化完成摘要，包括：
- 项目配置概览
- 已替换的 skill 列表
- Git hook 安装状态
- 可用的 skill 命令列表：
  - `/prd-analyst` — PRD 分析
  - `/solution-designer` — 方案设计
  - `/developer` — 代码开发
  - `/arch-reviewer` — 架构审查
  - `/code-reviewer` — 代码审查
  - `/test-engineer` — 测试工程师

## 标准开发工作流

```
/prd-analyst       → 拆解需求
       ↓
/solution-designer → 产出技术方案
       ↓
/arch-reviewer     → 审查方案（FAIL → 自动回到 solution-designer）
       ↓
/developer         → 编写代码
       ↓
/test-engineer     → 编写测试
       ↓
/code-reviewer     → 审查代码（FAIL → 自动回到 developer）
```
