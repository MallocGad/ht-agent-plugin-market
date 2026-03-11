# Notification System Lite Design

**Date**: 2026-02-02
**Status**: Implemented
**Version**: 1.0.0

## Overview

创建一个轻量级的通知系统插件 `notification-system-lite`，基于 Claude Code 内置的 `idle_prompt` 事件实现用户空闲通知，无需后台守护进程。

## Background

现有的 `notification-system` 插件使用自定义守护进程监控用户空闲状态，虽然功能强大且可配置，但存在以下问题：
- 需要管理后台进程生命周期
- 占用系统资源（虽然很少）
- 架构相对复杂

Claude Code 提供了内置的 `idle_prompt` 事件，可以在检测到用户空闲时触发通知。基于此事件可以实现一个更简单的轻量级版本。

## Requirements

### Functional Requirements

1. 记录用户每次输入的任务上下文（prompt、时间）
2. 检测 Claude Code 的 `idle_prompt` 事件
3. 发送包含任务上下文的通知（prompt 摘要、总时长、空闲时长）
4. 支持多通知渠道（Mac、钉钉、飞书）
5. 避免重复通知（标记已发送）
6. 自动清理过期状态文件

### Non-Functional Requirements

1. **零后台进程** - 完全依赖 Claude Code 内置事件
2. **简单架构** - 最小化组件和配置
3. **向后兼容** - 与 notification-system 共存，不冲突
4. **可靠性** - 状态文件损坏不影响系统运行

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Process                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  UserPromptSubmit Hook  ──►  task-start.sh                  │
│        │                          │                           │
│        │                          ▼                           │
│        │                   Create/Update {session_id}.state  │
│        │                   (session_id, start_time,          │
│        │                    last_input_time, prompt,         │
│        │                    notification_sent=false)         │
│        │                                                      │
│        ▼                                                      │
│  Claude 响应完成 + 用户空闲                                  │
│        │                                                      │
│        ▼                                                      │
│  Claude Code 检测到空闲 (内置机制)                          │
│        │                                                      │
│        ▼                                                      │
│  Notification(idle_prompt) Hook  ──►  send-notification.sh  │
│                                              │                │
│                                              ▼                │
│                                       Read state file        │
│                                       Check notification_sent│
│                                       Calculate durations    │
│                                       Send notifications     │
│                                       Mark notification_sent │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Input**: UserPromptSubmit → `task-start.sh` → Create/Update state file
2. **Idle Detection**: Claude Code detects idle → Trigger Notification(idle_prompt)
3. **Send Notification**: `send-notification.sh` → Read state → Send → Mark sent

## Detailed Design

### State Management

**State Directory**: `~/.claude/scripts/notification-lite/state/`

**State File Format** (`{session_id}.state`):
```json
{
  "session_id": "abc123",
  "start_time": 1738234567,
  "last_input_time": 1738234580,
  "prompt": "用户的输入 prompt",
  "notification_sent": false
}
```

**State Update Logic**:
- **New task**: Create state file with all fields
- **Subsequent input**: Update `last_input_time`, `prompt`, reset `notification_sent` to false, keep `start_time` unchanged
- **Notification sent**: Mark `notification_sent` to true
- **Cleanup**: Delete files older than 30 minutes

### Script Components

#### 1. `task-start.sh` (UserPromptSubmit Hook)

**Responsibilities**:
- Read JSON payload from stdin
- Extract `session_id` and `prompt`
- Check if state file exists
- New task: Create state file with all fields
- Subsequent input: Update `last_input_time`, `prompt`, reset `notification_sent`
- Cleanup old state files

**Key Logic**:
```bash
if state_file_exists "$session_id"; then
    # Update existing state
    write_state_file "$session_id" "last_input_time" "$current_time"
    write_state_file "$session_id" "prompt" "$prompt"
    write_state_file "$session_id" "notification_sent" "false"
else
    # Create new state
    write_state_file "$session_id" "session_id" "$session_id"
    write_state_file "$session_id" "start_time" "$current_time"
    write_state_file "$session_id" "last_input_time" "$current_time"
    write_state_file "$session_id" "prompt" "$prompt"
    write_state_file "$session_id" "notification_sent" "false"
fi
```

#### 2. `send-notification.sh` (Notification Hook)

**Responsibilities**:
- Read JSON payload from stdin
- Extract `session_id` and `notification_type`
- Verify `notification_type == "idle_prompt"`
- Read state file
- Check `notification_sent` flag (skip if true)
- Calculate total duration and idle duration
- Send notifications to enabled channels
- Mark `notification_sent = true`

**Key Logic**:
```bash
# Verify notification type
if [ "$notification_type" != "idle_prompt" ]; then
    exit 0
fi

# Check if already sent
if [[ "$notification_sent" == "true" ]]; then
    exit 0
fi

# Calculate durations
total_duration=$((current_time - start_time))
idle_duration=$((current_time - last_input_time))

# Send notifications
send_notification "$session_id" "$prompt" "$total_duration" "$idle_duration"

# Mark as sent
write_state_file "$session_id" "notification_sent" "true"
```

#### 3. `utils.sh` (Utility Functions)

**Functions**:
- Logging: `log_info`, `log_error`, `log_success`, `log_warning`, `log_debug`
- State management: `init_state_dir`, `write_state_file`, `read_state_file`, `state_file_exists`, `cleanup_old_state_files`
- Time: `get_current_timestamp`, `calculate_duration`, `format_duration`
- JSON: `get_json_value`, `is_json_true`
- String: `truncate_string`

#### 4. Notifiers

**Reused from notification-system**:
- `notifiers/mac.sh` - macOS system notifications
- `notifiers/dingtalk.sh` - DingTalk webhook
- `notifiers/lark.sh` - Lark webhook

### Configuration

**notification-config.json**:
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

**Hook Configuration** (`~/.claude/settings.json`):
```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/scripts/notification-lite/task-start.sh",
        "timeout": 5
      }]
    }],
    "Notification": [{
      "matcher": "idle_prompt",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/scripts/notification-lite/send-notification.sh",
        "timeout": 5
      }]
    }]
  }
}
```

### Notification Message Format

**Title**: "Claude Code - 需要用户输入"

**Subtitle**: "任务已空闲 {idle_duration}"

**Body**:
```
任务: {truncated_prompt}
总时长: {total_duration}
空闲时长: {idle_duration}
```

## Error Handling

### State File Issues

- **Missing state file**: Log warning, exit gracefully (may be new session)
- **Corrupted JSON**: Log error, skip this notification
- **Write failure**: Log error, don't crash

### Hook Payload Issues

- **Missing session_id**: Log error, exit with error code
- **Wrong notification_type**: Log debug, exit gracefully
- **Missing fields**: Use default values, continue

### Edge Cases

- **Fast user response**: Notification not sent (user inputs before idle detected)
- **Multiple sessions**: Each has independent state file
- **State file cleanup**: Old files removed after 30 minutes
- **Duplicate notifications**: Prevented by `notification_sent` flag

## Testing Strategy

### Manual Testing

1. Install plugin, verify hooks configured
2. Submit prompt, verify state file created
3. Wait for idle detection, verify notification sent
4. Submit another prompt, verify state updated and notification_sent reset
5. Verify state file cleanup after 30 minutes

### Verification Commands

```bash
# Check state files
ls -lh ~/.claude/scripts/notification-lite/state/*.state

# View state file content
cat ~/.claude/scripts/notification-lite/state/*.state | jq

# Check logs
tail -f ~/.claude/scripts/notification-lite/logs/notification.log

# Test notification manually
echo '{"session_id":"test","notification_type":"idle_prompt"}' | \
  ~/.claude/scripts/notification-lite/send-notification.sh
```

## Comparison with notification-system

| Feature | notification-system | notification-system-lite |
|---------|---------------------|--------------------------|
| Architecture | Custom daemon | Built-in idle_prompt |
| Background process | Yes | No |
| Idle threshold | Configurable (default 15s) | Fixed (~30-60s) |
| Resource usage | Low (daemon) | Zero |
| Maintenance | Process lifecycle | Zero |
| Flexibility | High | Low |
| Complexity | Medium | Low |
| Use case | Need custom threshold | Want simplicity |

## Benefits

1. **Zero Maintenance**: No daemon to manage, no process lifecycle
2. **Zero Resource Usage**: No background processes
3. **Simple Architecture**: Only 2 hook scripts + utilities
4. **Reliable**: Uses tested Claude Code functionality
5. **Easy to Understand**: Minimal moving parts

## Limitations

1. **Fixed Threshold**: Cannot customize idle time (controlled by Claude Code)
2. **Longer Idle Time**: ~30-60 seconds vs 15 seconds in full version
3. **Less Control**: Cannot adjust check intervals or timeouts

## Migration Plan

### Installation

1. Run `install.sh` to create directory structure
2. Copy scripts and configuration files
3. Auto-configure hooks in `~/.claude/settings.json`

### Coexistence with notification-system

- Different installation paths:
  - notification-system: `~/.claude/scripts/system-notify/`
  - notification-system-lite: `~/.claude/scripts/notification-lite/`
- Different hooks (can coexist):
  - notification-system: UserPromptSubmit, Stop, SessionEnd
  - notification-system-lite: UserPromptSubmit, Notification(idle_prompt)
- Users can choose which one to use

## Future Enhancements

1. Support more notification channels (Slack, Teams, etc.)
2. Configurable message templates
3. Integration with other Claude Code events
4. Statistics and analytics

## Approval

- [x] Design validated
- [x] Implementation completed
- [x] Documentation written
- [x] Ready for release
