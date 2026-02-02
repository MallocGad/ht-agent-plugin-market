# Changelog

All notable changes to the notification-system-lite plugin will be documented in this file.

## [1.0.0] - 2026-02-02

### Added

**Initial Release** - Lightweight notification system based on Claude Code's built-in `idle_prompt` event

- **Zero Background Processes**: No daemon, no resource overhead
- **Built-in Idle Detection**: Uses Claude Code's native `idle_prompt` notification event
- **Task Context Tracking**: Records prompt, start time, and last input time
- **Multi-Channel Support**: Mac system notifications, DingTalk, and Lark
- **Automatic State Management**:
  - Creates state files on user input
  - Updates state on subsequent inputs
  - Marks notification as sent to avoid duplicates
  - Auto-cleanup after 30 minutes
- **Simple Architecture**:
  - `task-start.sh` - UserPromptSubmit hook for state tracking
  - `send-notification.sh` - Notification(idle_prompt) hook for sending alerts
  - `utils.sh` - Shared utility functions
  - `notifiers/` - Channel-specific notification scripts

### Features

- **Notification Content**: Includes task prompt summary, total duration, and idle duration
- **Configuration**: Simple JSON config for enabling/disabling channels
- **Logging**: Complete logging to `~/.claude/scripts/notification-lite/logs/notification.log`
- **Security**: State files stored with 700 permissions (contains user prompts)

### Installation

- Automatic hook configuration via `install.sh`
- Configures both UserPromptSubmit and Notification(idle_prompt) hooks
- Creates directory structure and copies all necessary files

### Limitations

- **Fixed Idle Threshold**: Controlled by Claude Code (approximately 30-60 seconds), not configurable
- **No Custom Thresholds**: Unlike notification-system, cannot set custom idle durations

### Comparison with notification-system

**notification-system-lite** is simpler but less flexible:
- ✅ No background processes
- ✅ Zero maintenance
- ✅ Simpler architecture
- ❌ Fixed idle threshold (can't customize)
- ❌ Longer idle time (30-60s vs 15s default)

Choose **notification-system** if you need:
- Custom idle thresholds (< 30 seconds)
- Precise control over notification timing

Choose **notification-system-lite** if you want:
- Zero maintenance
- No background processes
- Simple, lightweight solution
