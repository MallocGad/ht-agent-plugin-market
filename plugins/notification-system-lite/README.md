# notification-system-lite

Claude Code 轻量级用户空闲通知系统。基于 Claude Code 内置的 `idle_prompt` 事件，当用户在 Claude 响应后长时间未输入时，自动发送提醒通知。

## 特性

- 🪶 **轻量级架构** - 无后台守护进程，零资源占用
- 🔔 **智能监控** - 基于 Claude Code 内置空闲检测
- 📱 **多渠道通知** - 支持 macOS、钉钉、飞书
- 🎯 **包含任务上下文** - 通知包含 prompt 摘要和时长信息
- ⚙️ **简单配置** - 最小化配置，开箱即用
- 📊 **完整日志** - 所有操作记录到日志文件

## 核心特性

- ✅ 基于 Claude Code 内置 `idle_prompt` 事件
- ✅ 无后台进程，零维护成本
- ✅ 自动记录任务上下文（prompt、开始时间）
- ✅ 用户输入时自动重置状态
- ✅ 自动清理过期状态文件（30分钟）
- ✅ 固定空闲阈值（由 Claude Code 控制，约 30-60 秒）

## Installation

```bash
/plugin install notification-system-lite from ht-agent-plugin-market
```

## 工作原理

系统使用两个 hook 脚本：

1. **task-start.sh** - 在用户提交 prompt 时记录任务状态
2. **send-notification.sh** - 在 Claude Code 检测到空闲时发送通知

当用户在 Claude 响应后超过一定时间（由 Claude Code 控制）未输入新消息时，系统会发送一次提醒通知。

### 工作流程

```
用户提交 Prompt
    ↓
task-start.sh 记录状态
(session_id, start_time, last_input_time, prompt)
    ↓
Claude 响应完成
    ↓
用户未输入（空闲）
    ↓
Claude Code 检测到空闲
    ↓
触发 Notification(idle_prompt) hook
    ↓
send-notification.sh 读取状态
    ↓
发送多渠道通知
    ↓
标记 notification_sent=true
```

## 配置

插件安装后，在 `~/.claude/settings.json` 中配置 hooks：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/notification-lite/task-start.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/notification-lite/send-notification.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## 配置选项

在 `~/.claude/scripts/notification-lite/notification-config.json` 中配置：

```json
{
  "enabled": true,
  "message": {
    "maxPromptLength": 50
  },
  "channels": {
    "mac": {
      "enabled": true,
      "sound": true
    },
    "dingtalk": {
      "enabled": false,
      "webhook": "",
      "secret": ""
    },
    "lark": {
      "enabled": false,
      "webhook": ""
    }
  }
}
```

**主要配置项**：
- `enabled` - 启用/禁用通知系统
- `message.maxPromptLength` - 通知中 prompt 的最大长度（默认 50 字符）
- `channels` - 配置各通知渠道（Mac、钉钉、飞书）

**注意**: 空闲阈值由 Claude Code 内置控制，不可配置（约 30-60 秒）。

## 架构说明

### 状态文件

系统在 `~/.claude/scripts/notification-lite/state/` 目录下为每个会话维护一个状态文件：

**文件名格式**: `{session_id}.state`

**内容示例**:
```json
{
  "session_id": "abc123",
  "start_time": 1738234567,
  "last_input_time": 1738234580,
  "prompt": "用户的输入 prompt",
  "notification_sent": false
}
```

### 状态更新逻辑

- **新任务**: 创建状态文件，记录所有字段
- **后续输入**: 更新 `last_input_time`、`prompt`，重置 `notification_sent`，保持 `start_time` 不变
- **发送通知**: 标记 `notification_sent=true`，避免重复通知
- **自动清理**: 30 分钟后自动删除状态文件

## 日志和调试

**日志文件位置**:
- `~/.claude/scripts/notification-lite/logs/notification.log` - 主日志

**查看日志**:
```bash
# 实时查看日志
tail -f ~/.claude/scripts/notification-lite/logs/notification.log
```

## 故障排除

**通知未发送**:
1. 检查配置文件中 `enabled: true`
2. 确认至少一个通知渠道已启用
3. 查看日志文件排查错误
4. 确认 Claude Code 已检测到空闲（等待足够时间）

**状态文件问题**:
1. 状态文件位于 `~/.claude/scripts/notification-lite/state/*.state`
2. 30分钟后自动清理
3. 可手动删除：`rm ~/.claude/scripts/notification-lite/state/*.state`

## 与 notification-system 的对比

| 特性 | notification-system | notification-system-lite |
|------|---------------------|--------------------------|
| 架构 | 自定义守护进程 | 基于 Claude Code 内置事件 |
| 资源占用 | 有后台进程 | 零后台进程 |
| 空闲阈值 | 可配置（默认 15 秒） | 固定（约 30-60 秒） |
| 维护成本 | 需要管理进程生命周期 | 零维护 |
| 灵活性 | 高（可自定义阈值） | 低（固定阈值） |
| 适用场景 | 需要短阈值或精确控制 | 追求简单、零维护 |

## Version

1.0.0

## Usage

See the skill documentation in `skills/notification-system-lite/SKILL.md`
