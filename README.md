# HT Agent Plugin Market

Claude Code 插件市场，提供一系列实用的 Claude Code 插件和技能，帮助提升开发效率。

## 插件列表

### notification-system
Claude Code 用户静默通知系统。当用户在 Claude 响应后长时间未输入时，自动发送提醒通知。

**特性**:
- 智能监控用户输入状态
- 多渠道通知支持（macOS、钉钉、飞书）
- 高效的后台守护进程架构
- 自动重置计时器

**安装**:
```bash
/plugin install notification-system from ht-agent-plugin-market
```

[查看详细文档](./plugins/notification-system/README.md)

---

### notification-system-lite
轻量级通知系统，notification-system 的简化版本。

**安装**:
```bash
/plugin install notification-system-lite from ht-agent-plugin-market
```

[查看详细文档](./plugins/notification-system-lite/README.md)

---

### wiki-tools
Confluence Wiki 管理工具，支持读取、更新、创建和管理 Wiki 页面。

**特性**:
- 创建新页面或子页面
- 获取页面内容（HTML/Markdown 格式）
- 更新页面内容或标题
- 追加内容到现有页面
- 从 URL 提取页面 ID

**安装**:
```bash
/plugin install wiki-tools from ht-agent-plugin-market
```

[查看详细文档](./plugins/wiki-tools/README.md)

---

### package-plugin
将技能打包为 Claude Code 插件并发布到市场的工具。

**安装**:
```bash
/plugin install package-plugin from ht-agent-plugin-market
```

[查看详细文档](./plugins/package-plugin/README.md)

---

## 如何使用插件市场

### 方法一：直接从 GitHub 安装（推荐）

使用插件的短名称直接安装：

```bash
/plugin install <plugin-name> from ht-agent-plugin-market
```

例如：
```bash
/plugin install notification-system from ht-agent-plugin-market
/plugin install wiki-tools from ht-agent-plugin-market
```

### 方法二：使用完整仓库路径

```bash
/plugin install <plugin-name> from MallocGad/ht-agent-plugin-market
```

例如：
```bash
/plugin install notification-system from MallocGad/ht-agent-plugin-market
```

### 方法三：本地安装

如果你已经克隆了本仓库到本地：

```bash
# 克隆仓库
git clone git@github.com:MallocGad/ht-agent-plugin-market.git

# 进入插件目录
cd ht-agent-plugin-market/plugins/<plugin-name>

# 使用 Claude Code 安装
/plugin install .
```

## 查看已安装的插件

```bash
/plugin list
```

## 卸载插件

```bash
/plugin uninstall <plugin-name>
```

## 更新插件

```bash
/plugin update <plugin-name>
```

## 贡献插件

欢迎贡献新的插件到这个市场！

### 插件目录结构

```
plugins/
└── your-plugin-name/
    ├── .claude-plugin/
    │   └── plugin.json          # 插件元数据
    ├── skills/
    │   └── your-skill-name/
    │       └── SKILL.md         # 技能定义
    ├── README.md                # 插件文档
    └── CHANGELOG.md             # 变更日志（可选）
```

### 提交流程

1. Fork 本仓库
2. 在 `plugins/` 目录下创建你的插件
3. 确保包含必要的文件（plugin.json、SKILL.md、README.md）
4. 提交 Pull Request

## 许可证

本项目采用 MIT 许可证。

## 联系方式

- GitHub: [MallocGad/ht-agent-plugin-market](https://github.com/MallocGad/ht-agent-plugin-market)
- Issues: [提交问题](https://github.com/MallocGad/ht-agent-plugin-market/issues)

## 相关资源

- [Claude Code 官方文档](https://docs.anthropic.com/claude/docs)
- [Claude Code CLI](https://github.com/anthropics/claude-code)
