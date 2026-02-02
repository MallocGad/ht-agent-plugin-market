# notification-system

Claude Code 用户静默通知系统。当用户在 Claude 响应后长时间未输入时，自动发送提醒通知。支持 Mac 系统通知、钉钉和飞书 IM 通知。

## 特性

- 🔔 智能监控用户输入状态（可配置静默阈值）
- 📱 多渠道通知支持（macOS、钉钉、飞书）
- ⚡ 高效的后台守护进程架构
- 🔄 自动重置计时器（用户输入时）
- 🎯 包含完整任务上下文的通知
- ⚙️ 灵活的配置选项
- 📊 完整的日志记录

## 核心特性 (v2.0.0)

- ✅ 基于状态监控的架构，替代旧的时间延迟方式
- ✅ 单一后台守护进程，监控所有活跃任务
- ✅ 用户输入时自动重置静默计时器
- ✅ 支持多任务并发监控
- ✅ 自动清理过期状态文件（24小时）
- ✅ 守护进程空闲自动退出，节省资源

## Installation

```bash
/plugin install notification-system from ht-agent-plugin-market
```

## 工作原理

系统使用三个 hook 脚本和一个后台守护进程：

1. **task-start.sh** - 在用户提交 prompt 时创建任务状态文件
2. **user-input-detected.sh** - 在用户输入时重置静默计时器
3. **task-complete.sh** - 在 Claude 响应完成时更新状态并启动守护进程
4. **task-monitor-daemon.sh** - 后台守护进程，每15秒检查所有任务的静默时长

当用户在 Claude 响应后超过配置的阈值（默认 15 秒）未输入新消息时，系统会发送一次提醒通知。

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
            "command": "bash ~/.claude/scripts/system-notify/task-start.sh",
            "timeout": 5
          },
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/system-notify/user-input-detected.sh",
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
```

## 配置选项

在 `~/.claude/scripts/system-notify/notification-config.json` 中配置：

```json
{
  "enabled": true,
  "silence_duration": 15,
  "state": {
    "directory": "~/.claude/scripts/system-notify/state/",
    "cleanup_after_hours": 24
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
- `silence_duration` - 静默阈值（秒），默认 15 秒
- `state.cleanup_after_hours` - 自动清理过期状态文件的时长（小时）
- `channels` - 配置各通知渠道（Mac、钉钉、飞书）

**注意**: 守护进程检查间隔固定为 15 秒，不可配置。

## 环境变量

可通过环境变量覆盖配置：

```bash
# 启用/禁用通知系统（默认：1）
export CLAUDE_NOTIFICATION_ENABLED=1

# 覆盖静默阈值（秒）
export CLAUDE_NOTIFICATION_THRESHOLD=30

# 启用调试日志
export CLAUDE_NOTIFICATION_DEBUG=1
```

## 架构说明

### 状态文件

系统在 `~/.claude/scripts/system-notify/state/` 目录下为每个任务维护一个状态文件：

**文件名格式**: `{task_id}.state`

**内容示例**:
```json
{
  "task_id": "session-123",
  "start_time": 1738234567,
  "last_response_time": 1738234580,
  "prompt": "用户的输入 prompt",
  "notification_sent": false
}
```

### 工作流程

1. **用户提交 Prompt**
   - `task-start.sh` 创建状态文件，记录开始时间和 prompt
   - `user-input-detected.sh` 重置 `last_response_time`

2. **Claude 响应完成**
   - `task-complete.sh` 更新 `last_response_time`
   - 检查并启动守护进程（如未运行）

3. **后台监控**
   - `task-monitor-daemon.sh` 每秒扫描所有状态文件
   - 计算静默时长 = 当前时间 - `last_response_time`
   - 当静默时长超过阈值且未发送通知时，发送提醒

4. **用户再次输入**
   - `user-input-detected.sh` 重置计时器
   - 清除 `notification_sent` 标志，允许新的通知

### 守护进程管理

- 守护进程使用 `nohup` 在后台运行
- PID 存储在 `~/.claude/scripts/system-notify/state/daemon.pid`
- 当所有任务完成后空闲超过 1 小时，自动退出
- 每次 Claude 响应时检查并重启（如已停止）

## 测试

```bash
# 测试任务启动
~/.claude/scripts/system-notify/test-task-start.sh

# 测试任务完成和守护进程
~/.claude/scripts/system-notify/test-task-complete.sh

# 测试用户输入检测
~/.claude/scripts/system-notify/test-user-input-detected.sh

# 测试守护进程监控
~/.claude/scripts/system-notify/test-task-monitor-daemon.sh

# 测试 hook payload 处理
~/.claude/scripts/system-notify/test-hook-payload.sh
```

## 日志和调试

**日志文件位置**:
- `~/.claude/scripts/system-notify/logs/notification.log` - 主日志
- `~/.claude/scripts/system-notify/logs/daemon.log` - 守护进程日志

**查看日志**:
```bash
# 实时查看主日志
tail -f ~/.claude/scripts/system-notify/logs/notification.log

# 实时查看守护进程日志
tail -f ~/.claude/scripts/system-notify/logs/daemon.log

# 检查守护进程状态
ps aux | grep task-monitor-daemon
```

## 故障排除

**通知未发送**:
1. 检查 `CLAUDE_NOTIFICATION_ENABLED=1`
2. 确认至少一个通知渠道已启用
3. 查看日志文件排查错误
4. 检查静默阈值是否合理

**守护进程未运行**:
1. 检查 `~/.claude/scripts/system-notify/state/daemon.pid`
2. 查看守护进程日志
3. 手动启动：`bash ~/.claude/scripts/system-notify/task-monitor-daemon.sh &`

**状态文件问题**:
1. 状态文件位于 `~/.claude/scripts/system-notify/state/*.state`
2. 24小时后自动清理
3. 可手动删除：`rm ~/.claude/scripts/system-notify/state/*.state`

## Version

2.0.3

## 迁移指南

### 从 v1.x 升级到 v2.0.0

**重大变更**:
- 通知触发机制从"任务完成时"改为"用户静默时"
- 移除了 `notify.sh` 脚本（功能整合到守护进程）
- 新增 `user-input-detected.sh` 和 `task-monitor-daemon.sh`
- 状态文件从 `tmp/` 移至 `state/` 目录
- 配置文件新增 `silence_duration` 和 `state` 配置项

**升级步骤**:
1. 运行 `./scripts/install.sh` 安装新脚本
2. 更新 `~/.claude/settings.json` 添加 `user-input-detected.sh` hook
3. 更新 `notification-config.json` 添加新配置项
4. 清理旧的临时文件：`rm -rf ~/.claude/scripts/system-notify/tmp/`
5. 测试新系统：运行测试脚本验证功能

## Usage

See the skill documentation in `skills/notification-system/SKILL.md`
