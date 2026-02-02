# Changelog

All notable changes to the notification-system plugin will be documented in this file.

## [2.0.4] - 2026-02-02

### Changed

**Daemon Lifecycle Optimization** - Improved resource management and cleanup

- **Inactivity Timeout**: Reduced from 3600 seconds (1 hour) to 600 seconds (10 minutes)
  - Daemon exits faster when no active tasks, reducing unnecessary resource usage
  - Next task automatically restarts daemon when needed
- **State File Cleanup**: Reduced from 24 hours to 30 minutes
  - Faster cleanup of stale state files
  - Aligned with daemon lifecycle for better consistency
- **SessionEnd Hook**: Added automatic daemon cleanup on Claude Code exit
  - New `stop-daemon.sh` script stops daemon when session ends
  - Prevents daemon from running after user closes Claude Code
  - Automatically configured during installation

### Added

- **`stop-daemon.sh`**: New script for graceful daemon shutdown on session end
- **Automatic SessionEnd Hook Configuration**: `install.sh` now configures SessionEnd hook automatically

### Benefits

- **Better Resource Management**: Daemon runs only when needed
- **Cleaner Shutdown**: No orphaned processes after Claude Code exits
- **Faster Cleanup**: State files removed within 30 minutes instead of 24 hours

## [2.0.3] - 2026-02-02

### Changed

**Performance Optimization** - Reduced daemon check frequency to minimize resource usage

- **Daemon Check Interval**: Changed from 1 second to 15 seconds
  - Reduces CPU usage and system load
  - Still provides timely notifications (within 15 seconds of threshold)
  - Check interval is now hardcoded (not configurable via `monitor_check_interval`)
- **Removed Configuration**: `state.monitor_check_interval` is no longer supported
  - All documentation updated to reflect fixed 15-second interval
  - Simplified configuration structure

### Benefits

- **Lower Resource Usage**: Daemon consumes less CPU and battery on idle systems
- **Simpler Configuration**: One less setting to manage
- **Maintained Effectiveness**: 15-second interval is sufficient for user silence detection

## [2.0.2] - 2026-01-31

### Changed

**Simplified Hook Architecture** - Merged user input detection logic into task-start.sh

- **Removed Non-Existent Hook**: Eliminated `UserInputDetected` hook (not supported by Claude Code API)
- **Merged Logic**: `task-start.sh` now handles both scenarios:
  - New task: Creates state file with task_id, start_time, prompt
  - Subsequent user input: Resets last_response_time and notification_sent flag
- **Reduced Complexity**: Only 2 hooks needed instead of 3
  - UserPromptSubmit → task-start.sh
  - Stop → task-complete.sh

### Removed

- `user-input-detected.sh` - Logic merged into task-start.sh
- `test-user-input-detected.sh` - No longer needed

### Benefits

- **Cleaner Architecture**: Single script handles all user input scenarios
- **API Compliant**: Only uses officially supported Claude Code hooks
- **Easier Maintenance**: Fewer scripts to manage
- **Same Functionality**: Timer reset still works correctly on user input

## [2.0.1] - 2026-01-31

### Reverted

Reverted from v2.1.0 simplified version back to v2.0.0 full-featured version.

- **Restored Custom Daemon Monitoring**: Background daemon with configurable threshold
- **Restored 15-Second Default Threshold**: Customizable via `silence_duration` configuration
- **Restored All Hooks**: UserPromptSubmit, Stop, UserPromptSubmit (for user input detection)
- **Restored Scripts**:
  - `task-complete.sh` - Stop hook handler
  - `user-input-detected.sh` - User input detection
  - `task-monitor-daemon.sh` - Background monitoring daemon
  - All test files and integration tests

### Reason for Revert

While v2.1.0's simplified architecture (using Claude Code's built-in 60s idle detection) was cleaner, the fixed 60-second threshold proved too long for many use cases. Users preferred the flexibility of a configurable threshold (default 15s).

## [2.1.0] - 2026-01-31 (Reverted)

### Breaking Changes

- **Idle Threshold Fixed to 60 Seconds**: Now uses Claude Code's built-in `idle_prompt` event (60s) instead of custom configurable threshold
  - Removed `silence_duration` configuration option
  - System automatically detects when Claude has been idle for 60+ seconds
- **Removed Custom Daemon**: No longer runs background monitoring process
  - Deleted `task-monitor-daemon.sh`
  - Deleted `task-complete.sh` (Stop hook)
  - Deleted `user-input-detected.sh`
- **Simplified Hook Configuration**: Only two hooks needed now
  - `UserPromptSubmit` → `task-start.sh`
  - `Notification(idle_prompt)` → `send-idle-notification.sh`

### Added

- **`send-idle-notification.sh`**: New lightweight script triggered by Claude Code's native idle detection
  - Responds to `Notification` event with `idle_prompt` matcher
  - Sends notifications using existing multi-channel infrastructure
  - No background process required

### Removed

- `task-monitor-daemon.sh` - Background daemon no longer needed
- `task-complete.sh` - Stop hook no longer required
- `user-input-detected.sh` - User input detection now handled by system
- `test-task-complete.sh` - Test for removed script
- `test-user-input-detected.sh` - Test for removed script
- `test-task-monitor-daemon.sh` - Test for removed script
- `test-integration.sh` - Integration tests for removed features
- `silence_duration` configuration option

### Benefits

- **Simpler Architecture**: 2,141 lines of code removed
- **No Background Processes**: Zero performance overhead when idle
- **Native Integration**: Leverages Claude Code built-in idle detection
- **Easier Maintenance**: Fewer moving parts, less complexity
- **Reliable**: Uses tested system functionality instead of custom implementation

### Migration from 2.0.0

If you're using 2.0.0 with custom `silence_duration` < 60 seconds, you'll need to:
1. Accept the 60-second threshold (system limitation)
2. Re-run `install.sh` to update hook configuration
3. Old scripts will be automatically replaced

If 60 seconds is too long for your use case, consider keeping 2.0.0.

## [2.0.0] - 2026-01-30

### Breaking Changes

- **Notification Trigger Changed**: System now monitors user silence instead of task completion
  - Previously: Notified when task execution exceeded time threshold
  - Now: Notifies when user doesn't provide input after Claude's response for configured duration
- **Removed `notify.sh`**: Notification dispatch logic integrated into `task-monitor-daemon.sh`
- **State File Location Changed**: Moved from `tmp/` to `state/` directory
  - Old: `~/.claude/scripts/system-notify/tmp/claude-task-*.json`
  - New: `~/.claude/scripts/system-notify/state/{task_id}.state`
- **Configuration Key Renamed**: `timeThreshold` changed to `silence_duration`
- **Hook Configuration Required**: New `user-input-detected.sh` hook must be added to UserPromptSubmit

### Added

- **Background Daemon Monitoring** (`task-monitor-daemon.sh`)
  - Single daemon process monitors all active tasks
  - Checks state files every second for silence threshold
  - Auto-exits after 1 hour of inactivity to conserve resources
  - PID tracking in `state/daemon.pid`
- **User Input Detection** (`user-input-detected.sh`)
  - New hook script to detect user input
  - Automatically resets silence timer when user provides input
  - Clears notification_sent flag to allow new notifications
- **State-Based Architecture**
  - Persistent state files in `~/.claude/scripts/system-notify/state/`
  - Each task has independent `.state` file with JSON format
  - State includes: task_id, start_time, last_response_time, prompt, notification_sent
- **Automatic State Cleanup**
  - State files older than 24 hours automatically deleted
  - Configurable cleanup interval via `state.cleanup_after_hours`
- **Enhanced Configuration**
  - New `state` section for daemon and state file settings
  - `silence_duration` - threshold for user silence (default: 15 seconds)
  - `cleanup_after_hours` - state file retention period (default: 24 hours)
- **Comprehensive Test Suite**
  - `test-task-start.sh` - Test task initialization
  - `test-task-complete.sh` - Test task completion and daemon startup
  - `test-user-input-detected.sh` - Test input detection and timer reset
  - `test-task-monitor-daemon.sh` - Test daemon monitoring logic
- **Separate Daemon Logging**
  - New log file: `logs/daemon.log` for background daemon activity
  - Separates daemon operations from hook execution logs

### Changed

- **`task-start.sh`** - Creates state files instead of temporary files
- **`task-complete.sh`** - Updates state and ensures daemon is running (removed immediate notification logic)
- **`utils.sh`** - Added state file management functions, daemon management, duration calculations
- **Installation** - Updated `install.sh` to create `state/` directory and copy new scripts
- **Documentation** - Completely rewritten to reflect new architecture and workflow

### Removed

- **`notify.sh`** - Entire script removed, functionality moved to daemon
- **Temporary file approach** - No longer using `/tmp/` for task state
- **Immediate task completion notifications** - System now monitors user silence instead

### Fixed

- More reliable notification delivery with persistent state
- Better resource management with single daemon process
- Improved multi-task handling with independent state files

### Migration Guide

**For users upgrading from v1.x:**

1. **Update hooks configuration** in `~/.claude/settings.json`:
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
     }]
   }
   ```

2. **Update configuration file** `~/.claude/scripts/system-notify/notification-config.json`:
   - Rename `timeThreshold` to `silence_duration`
   - Add new `state` section:
     ```json
     {
       "silence_duration": 15,
       "state": {
         "directory": "~/.claude/scripts/system-notify/state/",
         "cleanup_after_hours": 24
       }
     }
     ```
     Note: Daemon check interval is fixed at 15 seconds (not configurable).

3. **Run installation script** to update all files:
   ```bash
   cd plugins/notification-system/skills/notification-system/scripts
   ./install.sh
   ```

4. **Clean up old files**:
   ```bash
   rm -rf ~/.claude/scripts/system-notify/tmp/
   rm -f ~/.claude/scripts/system-notify/notify.sh
   ```

5. **Test the new system**:
   ```bash
   ~/.claude/scripts/system-notify/test-task-start.sh
   ~/.claude/scripts/system-notify/test-task-complete.sh
   ~/.claude/scripts/system-notify/test-user-input-detected.sh
   ~/.claude/scripts/system-notify/test-task-monitor-daemon.sh
   ```

**Behavior Changes to Expect:**

- Notifications will now be sent when you're silent after Claude responds (instead of when task completes)
- Timer resets automatically when you provide new input
- A background daemon process will run when tasks are active
- State files persist in `~/.claude/scripts/system-notify/state/` for up to 24 hours

## [1.0.2] - 2026-01-29

### Changed
- **重大目录结构重构**：将所有运行时文件集中到 `~/.claude/scripts/system-notify/` 目录
  - 主脚本：`~/.claude/scripts/system-notify/` （原 `~/.claude/scripts/`）
  - 通知器：`~/.claude/scripts/system-notify/notifiers/` （原 `~/.claude/scripts/notifiers/`）
  - 日志文件：`~/.claude/scripts/system-notify/logs/` （原 `~/.claude/logs/`）
  - 临时状态文件：`~/.claude/scripts/system-notify/tmp/` （原 `/tmp/`）
- 更新所有脚本中的路径引用以匹配新的目录结构
- 更新文档中的所有安装和测试路径示例
- 更新 hooks 配置示例以使用新路径

### Benefits
- 所有相关文件集中在一个子目录中，更易于管理和备份
- 日志和临时文件与插件代码放在一起，更清晰的组织结构
- 避免污染 `~/.claude` 根目录和系统 `/tmp` 目录

## [1.0.1] - 2026-01-29

### Fixed
- 修复 `task-complete.sh` 从环境变量获取 session_id 的问题，改为从 Stop hook 的 JSON payload 中读取
- 修复 `task-start.sh` 从环境变量获取 session_id 的问题，改为优先从 payload 中读取
- 修复 `utils.sh` 安全检查阻止读取 `/tmp/` 目录状态文件的问题
- 修复 `install.sh` 未复制测试脚本的问题
- 正确处理 hook payload 中的所有字段（session_id、transcript_path、cwd、permission_mode、hook_event_name、stop_hook_active）

### Added
- 从 transcript 文件中智能提取最后一条 assistant 消息作为通知摘要
- 新增 `test-hook-payload.sh` 测试脚本，用于测试完整的 hook payload 处理
- 新增 `examples/complete-payload-example.sh` 示例脚本，展示如何处理完整的 hook payload
- `utils.sh` 现在允许读取 `/tmp/` 和 `/private/tmp/` 目录（用于状态文件）
- `install.sh` 现在自动复制测试脚本到 `~/.claude/scripts/`

### Changed
- 更新 `install.sh` 中的 hooks 配置说明，使用正确的嵌套结构格式
- 增强 `task-complete.sh` 和 `task-start.sh` 的错误处理和日志记录
- 更新 README，添加 hook payload 格式说明和高级用法文档
- 安装说明中添加了两个测试脚本的使用方法

## [1.0.0] - 2026-01-28

### Added
- 初始版本
- 支持 Mac 系统通知
- 支持钉钉和飞书 IM 通知
- 可配置的时间阈值
- 完整的日志系统
