# 通知系统添加项目名称设计

## 需求

在 `notification-system-lite` 插件的通知消息中添加当前工作目录名称，让用户知道是哪个项目需要输入。

## 问题

当前通知消息不包含项目信息，当用户同时在多个项目中使用 Claude Code 时，无法区分是哪个项目需要用户输入。

## 解决方案

### 1. 获取项目名称

使用环境变量 `PWD` 获取当前工作目录的完整路径，然后使用 `basename` 提取目录名称。

示例：
- 完整路径：`/Users/moka/IdeaProjects/ht-agent-plugin-market`
- 提取结果：`ht-agent-plugin-market`

### 2. 修改通知消息格式

在消息正文的第一行添加项目名称。

**修改前**：
```
任务: 帮我优化一下通知系统
总时长: 5分30秒
空闲时长: 2分30秒
```

**修改后**：
```
项目: ht-agent-plugin-market
任务: 帮我优化一下通知系统
总时长: 5分30秒
空闲时长: 2分30秒
```

### 3. 适配所有通知渠道

需要修改三个通知渠道的消息格式：

#### Mac 通知
在 `message` 变量中添加项目名称作为第一行。

#### 钉钉通知
在 Markdown 格式的 `dingtalk_content` 中添加 `**项目**: ${project_name}`。

#### 飞书通知
在 `lark_content` 中添加项目名称作为第一行。

## 实现细节

### 修改文件

只需修改一个文件：`plugins/notification-system-lite/scripts/send-notification.sh`

### 代码变更

在 `send_notification()` 函数中：

1. 在第 55 行左右（构建消息之前）添加：
```bash
# 获取项目名称（当前工作目录名称）
local project_name=$(basename "$PWD")
```

2. 修改第 56-58 行的消息构建：
```bash
local message="项目: ${project_name}\n任务: ${truncated_prompt}\n总时长: ${total_duration_str}\n空闲时长: ${idle_duration_str}"
```

3. 修改第 81 行的钉钉消息：
```bash
local dingtalk_content="### ${title}\n\n**项目**: ${project_name}\n\n**任务**: ${truncated_prompt}\n\n**总时长**: ${total_duration_str}\n\n**空闲时长**: ${idle_duration_str}"
```

4. 修改第 96 行的飞书消息：
```bash
local lark_content="项目: ${project_name}\n任务: ${truncated_prompt}\n总时长: ${total_duration_str}\n空闲时长: ${idle_duration_str}"
```

## 优点

- 简单直接，只需修改一个文件
- 对所有通知渠道统一生效
- 不需要额外配置
- 不影响现有功能
- 项目名称始终是最新的（每次发送通知时动态获取）

## 测试验证

1. 触发一次通知
2. 检查 Mac 通知、钉钉通知、飞书通知中是否都包含项目名称
3. 验证项目名称是否正确（与当前工作目录名称一致）
