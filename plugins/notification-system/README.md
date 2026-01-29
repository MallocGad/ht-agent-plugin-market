# notification-system

Claude Code 长任务完成通知系统。支持 Mac 系统通知、钉钉和飞书 IM 通知。

## 特性

- 🚀 自动检测长任务（可配置阈值）
- 📱 多渠道通知支持（macOS、钉钉、飞书）
- 🎯 从对话记录提取智能摘要
- ⚙️ 灵活的配置选项
- 📊 完整的日志记录

## 核心改进 (v1.0.1)

- ✅ 正确处理 Stop hook 的 JSON payload（包括 session_id、transcript_path 等）
- ✅ 从 transcript 中智能提取最后的 assistant 消息作为通知摘要
- ✅ 支持完整的 hook 上下文信息（工作目录、权限模式等）
- ✅ 提供完整的示例脚本展示高级用法

## Installation

```bash
/plugin install notification-system from ht-agent-plugin-market
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
```

## Hook Payload 格式

Stop hook 会接收以下 JSON payload（通过 stdin）：

```json
{
  "session_id": "unique-session-id",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/current/working/directory",
  "permission_mode": "normal",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
```

## 测试

```bash
# 测试基本通知功能
~/.claude/scripts/system-notify/test-notification.sh

# 测试完整的 hook payload 处理
~/.claude/scripts/system-notify/test-hook-payload.sh
```

## 高级用法

参考 `scripts/examples/complete-payload-example.sh` 了解如何完整处理 hook payload 的所有字段。

## Version

1.0.2

## Usage

See the skill documentation in `skills/notification-system/SKILL.md`
