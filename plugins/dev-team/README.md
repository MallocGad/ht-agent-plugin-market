# dev-team

开发团队插件，预置标准开发流程中的多个角色 skill，通过初始化配置自动适配项目规范。

## 特性

- 📋 PRD 分析师 — 需求拆解、接口梳理、风险识别
- 🏗️ 方案设计师 — 技术方案设计、数据库设计、文件改动清单
- 💻 代码开发者 — 按规范编码，遵循分层架构
- 🔍 架构审查员 — 方案架构审查，FAIL 自动回到设计阶段
- 📝 Code Reviewer — 代码审查，FAIL 自动回到开发阶段
- 🧪 测试工程师 — 编写单测/集成测试，验证覆盖率
- 🔒 Git Pre-commit Hook — 强制 Code Review 后才能提交

## 安装

```bash
/plugin install dev-team from ht-agent-plugin-market
```

## 快速开始

```bash
# 1. 初始化项目配置
/dev-init

# 2. 标准开发工作流
/prd-analyst       # 需求分析
/solution-designer # 技术方案
/arch-reviewer     # 架构审查（FAIL → 自动回到方案设计）
/developer         # 编码开发
/test-engineer     # 编写测试
/code-reviewer     # 代码审查（FAIL → 自动回到开发）
```

## 工作流闭环

```
/prd-analyst → /solution-designer → /arch-reviewer
                                        │
                                   PASS → /developer → /test-engineer → /code-reviewer
                                   FAIL → 自动回到 /solution-designer       │
                                                                       PASS → 提交
                                                                       FAIL → 自动回到 /developer
```

## 重新初始化

```bash
/dev-init --reset
```

## Version

1.0.0
