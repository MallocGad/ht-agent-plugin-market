# User Silence Notification System Design

**Date**: 2026-01-30
**Status**: Approved
**Author**: Claude Code with User

## Overview

改进 notification-system 插件，从**任务完成通知**改为**用户无输入通知**。当 Claude 返回响应后，用户超过配置的阈值时长没有发送新消息时，系统自动发送提醒通知。

## Background

当前的 notification-system 在任务完成时发送通知，但这并不适用于需要用户参与的交互式场景。更实用的是监控用户是否在 Claude 响应后及时跟进，避免任务被遗忘。

## Requirements

### Functional Requirements

1. 记录 Claude 每次响应的时间
2. 监控用户是否在阈值时间内发送新输入
3. 如果超时未输入，发送一次提醒通知
4. 通知中包含任务的完整上下文（开始时间、prompt、总耗时）
5. 用户输入后重置计时器

### Non-Functional Requirements

1. 性能：使用单一全局监控进程，避免多进程资源占用
2. 可靠性：状态文件损坏不影响系统运行
3. 可配置：复用现有的 CLAUDE_NOTIFICATION_THRESHOLD 配置
4. 清理：废弃旧的任务完成通知逻辑

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
│        │                   Create {task_id}.state            │
│        │                   (start_time, prompt)              │
│        │                                                      │
│        ▼                                                      │
│  user-input-detected.sh  ──►  Update last_response_time     │
│                                                               │
│  Stop Hook  ──►  task-complete.sh                           │
│                          │                                    │
│                          ▼                                    │
│                   Update last_response_time                  │
│                   Start task-monitor-daemon (if not running) │
│                                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Global Background Monitor Process               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  task-monitor-daemon.sh                                      │
│        │                                                      │
│        ▼                                                      │
│   Loop every 1 second:                                       │
│     - Scan all *.state files                                 │
│     - Check if (now - last_response_time) >= threshold       │
│     - If yes && !notification_sent:                          │
│         ├─► Read task context (start_time, prompt)          │
│         ├─► Send notification via channels                   │
│         └─► Mark notification_sent = true                    │
│     - Clean up old state files (>24h)                        │
│     - Exit if no active tasks for >1 hour                    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Task Start**: UserPromptSubmit → `task-start.sh` → Create state file
2. **Claude Response**: Stop → `task-complete.sh` → Update state → Start daemon
3. **Monitoring**: Daemon checks all tasks every second
4. **Timeout**: Daemon detects timeout → Send notification → Mark sent
5. **User Input**: UserPromptSubmit → `user-input-detected.sh` → Reset timer

## Detailed Design

### State Management

**State Directory**: `~/.claude/scripts/system-notify/state/`

**State File Format** (`{task_id}.state`):
```json
{
  "task_id": "xxx",
  "start_time": 1234567890,
  "last_response_time": 1234567900,
  "prompt": "user's input prompt here",
  "notification_sent": false,
  "monitor_pid": 12345
}
```

**Cleanup Policy**: Delete state files older than 24 hours

### Script Components

#### 1. `task-start.sh` (Modified)

**Responsibilities**:
- Initialize state directory
- Create `{task_id}.state` file with:
  - `task_id` from hook payload
  - `start_time` = current timestamp
  - `prompt` from hook payload
  - `notification_sent` = false
- Clean up old state files (>24h)

#### 2. `task-complete.sh` (Modified)

**Responsibilities**:
- Read `{task_id}.state`
- Update `last_response_time` = current timestamp
- Check if `task-monitor-daemon` is running
- If not running, start `task-monitor-daemon.sh` in background

**Removed Logic**:
- ~~Check task duration against threshold~~
- ~~Call `notify.sh` to send immediate notification~~

#### 3. `task-monitor-daemon.sh` (New)

**Responsibilities**:
- Check if already running (prevent duplicate daemons)
- Enter infinite loop:
  - Sleep 1 second
  - Scan all `*.state` files in state directory
  - For each task:
    - Calculate `silence_duration = now - last_response_time`
    - If `silence_duration >= threshold` AND `!notification_sent`:
      - Read task context (start_time, prompt)
      - Calculate total task duration
      - Call notification channels (mac, dingtalk, lark)
      - Mark `notification_sent = true` in state file
  - Clean up stale state files
  - If no active tasks for >1 hour, exit to free resources

**Daemon Management**:
- Store PID in `~/.claude/scripts/system-notify/state/daemon.pid`
- Use `nohup` to detach from parent process
- Redirect output to log file

#### 4. `user-input-detected.sh` (New)

**Responsibilities**:
- Extract `task_id` from hook payload
- Update `{task_id}.state`:
  - `last_response_time` = current timestamp (reset timer)
  - `notification_sent` = false (allow new notification if silence again)

#### 5. `utils.sh` (Modified)

**New Functions**:
- `read_state_file(task_id)` - Read and parse state JSON
- `write_state_file(task_id, data)` - Write state JSON
- `is_daemon_running()` - Check if daemon process is alive
- `start_daemon()` - Start daemon in background
- `calculate_duration(start, end)` - Calculate time difference

**Removed Functions**:
- ~~Old notification dispatch logic~~

### Configuration

**Environment Variables** (unchanged):
- `CLAUDE_NOTIFICATION_ENABLED` - Enable/disable system (default: 1)
- `CLAUDE_NOTIFICATION_THRESHOLD` - Silence timeout in seconds (default: 15)
- `CLAUDE_NOTIFICATION_DEBUG` - Debug logging (default: 0)

**notification-config.json** (new fields):
```json
{
  "state": {
    "directory": "~/.claude/scripts/system-notify/state/",
    "cleanup_after_hours": 24,
    "monitor_check_interval": 1
  },
  "channels": {
    "mac": { "enabled": true },
    "dingtalk": { "enabled": false },
    "lark": { "enabled": false }
  }
}
```

**Hook Configuration** (`~/.claude/settings.json`):
```json
{
  "UserPromptSubmit": [{
    "hooks": [
      {
        "type": "command",
        "command": "~/.claude/scripts/system-notify/task-start.sh",
        "timeout": 5
      },
      {
        "type": "command",
        "command": "~/.claude/scripts/system-notify/user-input-detected.sh",
        "timeout": 5
      }
    ]
  }],
  "Stop": [{
    "hooks": [{
      "type": "command",
      "command": "~/.claude/scripts/system-notify/task-complete.sh",
      "timeout": 10
    }]
  }]
}
```

### Notification Message Format

**Title**: "Claude Code - User Input Needed"

**Body**:
```
Task: {first 50 chars of prompt}...
Started: {start_time formatted}
Duration: {total_duration} seconds
Waiting for your input for {silence_duration} seconds
```

## Error Handling

### State File Issues

- **Missing state file**: Log warning, use default values, continue
- **Corrupted JSON**: Log error, skip this task, continue with others
- **Write failure**: Log error, don't crash

### Process Management

- **Daemon already running**: Skip starting new daemon
- **Daemon crashed**: `task-complete.sh` will restart it
- **PID file stale**: Check if process alive, clean up if dead

### Edge Cases

- **Fast task completion**: User inputs before timeout → No notification
- **Multiple concurrent tasks**: Each has independent state file
- **System time change**: Use monotonic timestamps where possible
- **Disk full**: Fail gracefully, log error

## Testing Strategy

### Unit Tests

- State file read/write functions
- Time calculation functions
- Daemon startup/shutdown logic

### Integration Tests

1. **Normal flow**: Start task → Response → Wait > threshold → Verify notification
2. **User input before timeout**: Start → Response → User input → Verify no notification
3. **Multiple tasks**: Start 3 tasks → Verify each monitored independently
4. **Daemon restart**: Kill daemon → New response → Verify daemon restarts

### Manual Testing

- Run `test-notification.sh` to verify channels
- Simulate long silence and verify notification
- Check daemon resource usage with `top`

## Migration Plan

### Phase 1: Code Cleanup

1. Delete `notify.sh` (entire file)
2. Remove old notification logic from `task-complete.sh`
3. Remove deprecated functions from `utils.sh`

### Phase 2: Implementation

1. Implement new functions in `utils.sh`
2. Modify `task-start.sh`
3. Modify `task-complete.sh`
4. Create `task-monitor-daemon.sh`
5. Create `user-input-detected.sh`

### Phase 3: Testing

1. Test individual scripts
2. Integration testing with hooks
3. Performance testing (resource usage)

### Phase 4: Documentation

1. Update README.md
2. Update SKILL.md
3. Update installation instructions

## Performance Considerations

### Resource Usage

- **Single daemon process**: ~2-5 MB memory, negligible CPU
- **Check interval**: 1 second (configurable)
- **State files**: ~1 KB per task, cleaned up after 24h

### Scalability

- Can handle 100+ concurrent tasks efficiently
- Daemon auto-exits when idle to free resources
- State files stored in filesystem, no memory bloat

## Security Considerations

- State files contain user prompts → Set proper file permissions (600)
- Daemon PID file → Prevent unauthorized access
- Webhook URLs in config → Already protected by existing system

## Future Enhancements

1. Configurable check interval per channel
2. Multiple notification thresholds (warn at 30s, alert at 60s)
3. Web dashboard to view active tasks
4. Integration with more IM platforms (Slack, Teams)

## Rollback Plan

If issues arise:
1. Revert to previous git commit
2. Restore old `notify.sh` logic
3. Update hook configuration to old version

All changes are version controlled, safe to rollback.

## Approval

- [x] User approved architecture
- [x] User approved component design
- [x] User approved configuration
- [x] User approved error handling
- [x] Ready for implementation
