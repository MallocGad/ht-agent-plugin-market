---
name: notification-system
description: Claude Code 用户静默通知系统。当用户在 Claude 响应后长时间未输入时自动发送提醒通知，支持 Mac 系统通知、钉钉和飞书 IM 通知。
---

# Claude Code Notification System Skill

## Overview

The notification-system skill monitors user input activity and automatically sends reminder notifications when users remain silent after Claude's response for a configurable duration. This helps prevent tasks from being forgotten and ensures timely follow-up on ongoing work.

### Key Features

- **🔔 Smart Silence Monitoring**: Tracks time since Claude's last response and alerts when user input is overdue
- **🔄 Automatic Timer Reset**: Resets the silence timer whenever user provides new input
- **⚡ Efficient Background Daemon**: Single daemon process monitors all active tasks with minimal resource usage
- **🖥️ Mac System Notifications**: Native macOS notifications with optional sound alerts
- **💬 IM Notifications**: Support for DingTalk (钉钉) and Lark (飞书) bot notifications
- **⚙️ Flexible Configuration**: Customizable silence thresholds, notification channels, and message formats
- **📊 Complete Logging**: All notification activities are logged for debugging and auditing
- **🔄 Graceful Degradation**: Notification failures never block the main task flow, system continues normally
- **⚡ Performance**: Hook execution time < 100ms, no impact on main workflow

## How It Works

The system uses a state-based monitoring approach with three hook scripts and a background daemon:

1. **Task Start** (`task-start.sh`): When user submits a prompt, creates a state file with task metadata
2. **User Input Detection** (`user-input-detected.sh`): Resets the silence timer when user provides input
3. **Task Complete** (`task-complete.sh`): Updates state when Claude responds and ensures daemon is running
4. **Background Monitor** (`task-monitor-daemon.sh`): Daemon checks all tasks every 15 seconds and sends notifications when silence threshold is exceeded

### When Notifications Are Sent

A notification is sent when:
- Claude has completed a response (Stop hook triggered)
- User has not provided new input for longer than the configured threshold (default: 15 seconds)
- No notification has been sent for this silence period yet

The notification includes:
- Original task prompt (first 50 characters)
- Task start time
- Total task duration
- Current silence duration

## Quick Start

### 1. Environment Variables

Set up these environment variables to control notification behavior:

```bash
# Enable/disable the entire notification system (default: 1)
export CLAUDE_NOTIFICATION_ENABLED=1

# Enable debug logging for troubleshooting
export CLAUDE_NOTIFICATION_DEBUG=0

# Override silence threshold in seconds (optional)
export CLAUDE_NOTIFICATION_THRESHOLD=15
```

### 2. Installing Dependencies

Run the installation script to set up everything automatically:

```bash
./scripts/install.sh
```

This script will:
- Create the `~/.claude` directory structure
- Copy all required script files
- Create a default configuration file
- Set appropriate execute permissions on all scripts

### 3. Configuring Claude Code Hooks

Edit `~/.claude/settings.json` to add the notification hooks:

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

The `UserPromptSubmit` hooks capture task start time and reset the silence timer on user input, while the `Stop` hook updates state when Claude responds and ensures the monitoring daemon is running.

### 4. Testing Notifications

Verify that the system works correctly with the test scripts:

```bash
# Test task start hook
~/.claude/scripts/system-notify/test-task-start.sh

# Test task complete hook and daemon startup
~/.claude/scripts/system-notify/test-task-complete.sh

# Test user input detection
~/.claude/scripts/system-notify/test-user-input-detected.sh

# Test daemon monitoring logic
~/.claude/scripts/system-notify/test-task-monitor-daemon.sh
```

These scripts will verify that state files are created correctly, the daemon starts properly, and notifications are sent when the silence threshold is exceeded.

## Core Operations

### Mac System Notifications Setup

Mac notifications are the simplest channel to set up and work out of the box on macOS systems.

**Configuration in `~/.claude/scripts/system-notify/notification-config.json`:**

```json
{
  "channels": {
    "mac": {
      "enabled": true,
      "sound": true
    }
  }
}
```

**Troubleshooting:**
- If notifications don't appear, check System Preferences > Notifications > Terminal/Console
- If `terminal-notifier` is not available, install via: `brew install terminal-notifier`
- Ensure the terminal application has notification permissions

**Example Notification:**

```
┌─────────────────────────────────────┐
│   Claude Code - User Input Needed   │
│                                     │
│   Task: Implementing notification...│
│   Started: 2026-01-30 14:30:00     │
│   Duration: 2min 15sec              │
│   Waiting for: 20 seconds           │
└─────────────────────────────────────┘
```

### DingTalk (钉钉) Notifications Setup

DingTalk notifications allow you to receive alerts in your DingTalk groups.

**Getting Your Webhook:**

1. Open DingTalk application
2. Navigate to the group chat where you want to receive notifications
3. Click the settings icon (⚙️) in the top-right corner
4. Select "Intelligent Group Assistant" → "Add Bot"
5. Choose "Custom" bot type
6. Set a bot name and configure message type filters
7. Copy the webhook URL and optionally the signature key

**Configuration:**

```json
{
  "channels": {
    "dingtalk": {
      "enabled": true,
      "webhook": "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN",
      "secret": "YOUR_SIGNATURE_SECRET"
    }
  }
}
```

**Parameters:**
- `webhook`: Required. The complete webhook URL provided by DingTalk
- `secret`: Optional. The signature secret for additional security

**Testing Your Webhook:**

```bash
curl -X POST https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN \
  -H 'Content-Type: application/json' \
  -d '{
    "msgtype": "text",
    "text": {
      "content": "Test message from notification system"
    }
  }'
```

### Lark (飞书) Notifications Setup

Lark (Feishu) notifications integrate with your Lark workspace bot.

**Getting Your Webhook:**

1. Open Lark application
2. Go to the group chat where you want notifications
3. Click on "Group Settings"
4. Select "Group Bots"
5. Click "Add Bot"
6. Choose "Custom Bot"
7. Copy the webhook URL

**Configuration:**

```json
{
  "channels": {
    "lark": {
      "enabled": true,
      "webhook": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_TOKEN"
    }
  }
}
```

**Parameters:**
- `webhook`: Required. The complete webhook URL provided by Lark

**Testing Your Webhook:**

```bash
curl -X POST https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_TOKEN \
  -H 'Content-Type: application/json' \
  -d '{
    "msg_type": "text",
    "content": {
      "text": "Test message from notification system"
    }
  }'
```

### Message Configuration

Customize what information is included in notifications:

**Configuration:**

```json
{
  "message": {
    "includePrompt": true,
    "includeDuration": true,
    "includeTimestamp": true,
    "maxPromptLength": 100
  }
}
```

**IM Notification Example:**

```
🔔 Claude Code - User Input Needed

Task: Implementing notification functionality for Claude Code...

Started: 2026-01-30 14:30:00
Duration: 2min 15sec
Waiting for your input for: 20 seconds
```

## Configuration Reference

### Complete Configuration File

A complete `~/.claude/scripts/system-notify/notification-config.json` with all options:

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
      "webhook": "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN",
      "secret": ""
    },
    "lark": {
      "enabled": false,
      "webhook": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_TOKEN"
    }
  },
  "message": {
    "includePrompt": true,
    "includeDuration": true,
    "includeTimestamp": true,
    "maxPromptLength": 100
  }
}
```

### Global Settings

| Configuration | Type | Default | Description | Example |
|---|---|---|---|---|
| `enabled` | boolean | `true` | Enable/disable the entire notification system | `false` |
| `silence_duration` | number | `15` | Silence threshold in seconds before triggering notification | `30` |

### State Management

| Configuration | Type | Default | Description | Example |
|---|---|---|---|---|
| `state.directory` | string | `~/.claude/scripts/system-notify/state/` | Directory for state files | Custom path |
| `state.cleanup_after_hours` | number | `24` | Hours before cleaning up old state files | `48` |

**Note**: The daemon check interval is fixed at 15 seconds and cannot be configured.

### Mac Notifications

| Configuration | Type | Default | Description | Example |
|---|---|---|---|---|
| `channels.mac.enabled` | boolean | `true` | Enable Mac system notifications | `false` |
| `channels.mac.sound` | boolean | `true` | Play sound when Mac notification appears | `false` |

### DingTalk Notifications

| Configuration | Type | Default | Description | Example |
|---|---|---|---|---|
| `channels.dingtalk.enabled` | boolean | `false` | Enable DingTalk bot notifications | `true` |
| `channels.dingtalk.webhook` | string | `""` | DingTalk robot webhook URL (required if enabled) | `https://oapi.dingtalk.com/robot/send?access_token=abc123` |
| `channels.dingtalk.secret` | string | `""` | DingTalk signature secret for webhook security (optional) | `your_secret_key_here` |

### Lark Notifications

| Configuration | Type | Default | Description | Example |
|---|---|---|---|---|
| `channels.lark.enabled` | boolean | `false` | Enable Lark bot notifications | `true` |
| `channels.lark.webhook` | string | `""` | Lark webhook URL (required if enabled) | `https://open.feishu.cn/open-apis/bot/v2/hook/xyz789` |

### Message Format

| Configuration | Type | Default | Description | Example |
|---|---|---|---|---|
| `message.includePrompt` | boolean | `true` | Include task prompt/description in notification | `false` |
| `message.includeDuration` | boolean | `true` | Include task execution duration in notification | `false` |
| `message.includeTimestamp` | boolean | `true` | Include task completion timestamp in notification | `false` |
| `message.maxPromptLength` | number | `100` | Maximum characters to include from task prompt | `200` |

### Environment Variable Overrides

Environment variables can override configuration file settings:

| Environment Variable | Type | Description |
|---|---|---|
| `CLAUDE_NOTIFICATION_ENABLED` | `0` or `1` | Override the `enabled` setting |
| `CLAUDE_NOTIFICATION_THRESHOLD` | number | Override the `silence_duration` in seconds |
| `CLAUDE_NOTIFICATION_DEBUG` | `0` or `1` | Enable debug logging to stdout |

## Troubleshooting

### Common Issues and Solutions

#### Issue: Mac notifications not appearing

**Symptoms:** Task completes, but no Mac notification shows

**Solutions:**
1. Verify that `channels.mac.enabled` is set to `true` in configuration
2. Check System Preferences → Notifications → Terminal (or your terminal app)
3. Ensure the terminal app has notification permissions
4. Install terminal-notifier if missing: `brew install terminal-notifier`
5. Check logs: `tail -f ~/.claude/scripts/system-notify/logs/notification.log`

#### Issue: DingTalk/Lark notifications not received

**Symptoms:** No message appears in IM, or connection timeout errors

**Solutions:**
1. Verify that `channels.dingtalk.enabled` or `channels.lark.enabled` is `true`
2. Double-check the webhook URL is complete and correct
3. Test webhook manually with curl (see Core Operations section)
4. Verify network connectivity to external services
5. Check logs for detailed error messages
6. For DingTalk, verify signature secret if configured

#### Issue: Notification not sent after silence

**Symptoms:** User remains silent after Claude's response, but no notification appears

**Solutions:**
1. Verify that `enabled` is `true` and `silence_duration` is appropriate
2. Confirm at least one notification channel is enabled
3. Check daemon is running: `ps aux | grep task-monitor-daemon`
4. Check state files exist: `ls ~/.claude/scripts/system-notify/state/*.state`
5. Review daemon logs: `tail -f ~/.claude/scripts/system-notify/logs/daemon.log`
6. Ensure silence duration actually exceeds threshold

#### Issue: Daemon not running

**Symptoms:** No background process monitoring tasks

**Solutions:**
1. Check daemon PID file: `cat ~/.claude/scripts/system-notify/state/daemon.pid`
2. Verify process is alive: `ps -p $(cat ~/.claude/scripts/system-notify/state/daemon.pid)`
3. Review daemon logs for crash information
4. Manually start daemon: `bash ~/.claude/scripts/system-notify/task-monitor-daemon.sh &`
5. Check disk space: `df -h ~/.claude`

#### Issue: Timer not resetting on user input

**Symptoms:** Notification sent even after user provides input

**Solutions:**
1. Verify `user-input-detected.sh` hook is configured in settings.json
2. Check hook execution: Enable debug mode and watch logs
3. Verify state file is being updated: `cat ~/.claude/scripts/system-notify/state/*.state`
4. Ensure hook timeout is sufficient (5 seconds recommended)

#### Issue: Script permission errors

**Symptoms:** "Permission denied" when running scripts

**Solutions:**
1. Check file permissions: `ls -l ~/.claude/scripts/system-notify/`
2. Fix permissions: `chmod +x ~/.claude/scripts/system-notify/**/*.sh`
3. Run install script again: `./scripts/install.sh`

#### Issue: Hook timeout warnings

**Symptoms:** Claude Code displays "Hook timeout" or similar messages

**Solutions:**
1. These scripts are designed to complete in < 100ms
2. Check system resources: `top` or `Activity Monitor`
3. Verify adequate disk space: `df -h ~`
4. Check if other processes are consuming resources
5. Review logs for actual execution time

### Debugging Tips

#### Enable Debug Logging

For detailed execution information:

```bash
export CLAUDE_NOTIFICATION_DEBUG=1
```

This enables verbose logging that shows:
- Script execution start/end times
- Configuration loading details
- Channel-specific debug info
- Error details and stack traces

#### View Notification Logs

All notification activities are logged:

```bash
# Watch main logs in real-time
tail -f ~/.claude/scripts/system-notify/logs/notification.log

# Watch daemon logs in real-time
tail -f ~/.claude/scripts/system-notify/logs/daemon.log

# View recent entries
tail -20 ~/.claude/scripts/system-notify/logs/notification.log

# Search for errors
grep ERROR ~/.claude/scripts/system-notify/logs/*.log

# View specific date
grep "2026-01-30" ~/.claude/scripts/system-notify/logs/notification.log
```

#### Log File Locations

- **Notification Log**: `~/.claude/scripts/system-notify/logs/notification.log`
- **Daemon Log**: `~/.claude/scripts/system-notify/logs/daemon.log`
- **State Files**: `~/.claude/scripts/system-notify/state/*.state` (auto-cleaned after 24h)
- **Daemon PID**: `~/.claude/scripts/system-notify/state/daemon.pid`
- **Configuration**: `~/.claude/scripts/system-notify/notification-config.json`

#### Manual Webhook Testing

Test a DingTalk webhook:

```bash
curl -X POST "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "msgtype": "text",
    "text": {
      "content": "Manual test notification"
    }
  }'
```

Test a Lark webhook:

```bash
curl -X POST "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "msg_type": "text",
    "content": {
      "text": "Manual test notification"
    }
  }'
```

#### Run Test Scripts

Comprehensive tests that validate all components:

```bash
# Test task start hook
~/.claude/scripts/system-notify/test-task-start.sh

# Test task complete hook and daemon startup
~/.claude/scripts/system-notify/test-task-complete.sh

# Test user input detection
~/.claude/scripts/system-notify/test-user-input-detected.sh

# Test daemon monitoring logic
~/.claude/scripts/system-notify/test-task-monitor-daemon.sh
```

Output will show success/failure for each component with detailed error messages if problems occur.

## Script Details

### Directory Structure

```
~/.claude/
├── settings.json                     # Claude Code settings with hooks
└── scripts/
    └── system-notify/                # Notification system directory
        ├── notification-config.json   # User configuration file
        ├── task-start.sh             # Triggered on UserPromptSubmit event
        ├── user-input-detected.sh    # Triggered on UserPromptSubmit event (resets timer)
        ├── task-complete.sh          # Triggered on Stop event
        ├── task-monitor-daemon.sh    # Background daemon monitoring silence
        ├── utils.sh                  # Shared utility functions
        ├── test-task-start.sh        # Test script for task start
        ├── test-task-complete.sh     # Test script for task complete
        ├── test-user-input-detected.sh # Test script for user input
        ├── test-task-monitor-daemon.sh # Test script for daemon
        ├── notifiers/
        │   ├── mac.sh                # Mac system notification handler
        │   ├── dingtalk.sh           # DingTalk notification handler
        │   └── lark.sh               # Lark notification handler
        ├── logs/
        │   ├── notification.log      # Main notification activity log
        │   └── daemon.log            # Daemon process log
        └── state/
            ├── daemon.pid            # Daemon process ID
            └── *.state               # Task state files (auto-cleaned after 24h)
```

### Script Purposes

#### `task-start.sh`
- **Hook Event**: UserPromptSubmit
- **Purpose**: Initializes task state when user submits a prompt
- **Actions**:
  - Creates state directory if not exists
  - Creates `{task_id}.state` file with start time and prompt
  - Cleans up old state files (>24h)
- **Execution Time**: < 50ms
- **Side Effects**: Creates `~/.claude/scripts/system-notify/state/{task_id}.state`

#### `user-input-detected.sh`
- **Hook Event**: UserPromptSubmit
- **Purpose**: Resets the silence timer when user provides input
- **Actions**:
  - Updates `last_response_time` in state file
  - Clears `notification_sent` flag to allow new notifications
- **Execution Time**: < 50ms
- **Side Effects**: Modifies existing state file

#### `task-complete.sh`
- **Hook Event**: Stop
- **Purpose**: Updates state when Claude responds and ensures daemon is running
- **Actions**:
  - Updates `last_response_time` in state file
  - Checks if daemon is running
  - Starts daemon if not running
- **Execution Time**: < 100ms
- **Side Effects**: Updates state file, may start daemon process

#### `task-monitor-daemon.sh`
- **Purpose**: Background daemon that monitors all tasks for silence
- **Actions**:
  - Runs in background with `nohup`
  - Checks all state files every 15 seconds
  - Calculates silence duration for each task
  - Sends notification when threshold exceeded
  - Marks `notification_sent` in state file
  - Cleans up old state files
  - Auto-exits after 1 hour of inactivity
- **Execution Time**: Continuous background process
- **Side Effects**: Updates state files, sends notifications, creates daemon.pid

#### `utils.sh`
- **Purpose**: Shared utility functions used by other scripts
- **Key Functions**:
  - State file read/write operations
  - Configuration loading and parsing
  - Time formatting utilities
  - Logging helpers
  - Error handling functions
  - Daemon management (check if running, start daemon)
  - Duration calculation

#### `notifiers/mac.sh`
- **Purpose**: Send macOS system notifications
- **Uses**: `terminal-notifier` command-line utility
- **Actions**:
  - Formats notification title and body
  - Invokes `terminal-notifier` with appropriate options
  - Handles sound playback if enabled
- **Requirements**: `terminal-notifier` installed via Homebrew

#### `notifiers/dingtalk.sh`
- **Purpose**: Send notifications via DingTalk bot webhook
- **Actions**:
  - Formats message in DingTalk markdown format
  - Calculates HMAC signature if secret is configured
  - Makes HTTP POST request to webhook
  - Parses response for success/failure
- **Requirements**: `curl` utility and network access

#### `notifiers/lark.sh`
- **Purpose**: Send notifications via Lark bot webhook
- **Actions**:
  - Formats message in Lark rich card format
  - Makes HTTP POST request to webhook
  - Parses response for success/failure
- **Requirements**: `curl` utility and network access

### Workflow Explanation

**Complete notification workflow:**

1. **User Submits Prompt** (< 50ms)
   - User submits a prompt in Claude Code
   - `task-start.sh` hook executes
   - Creates state file with start time and prompt
   - `user-input-detected.sh` hook executes
   - Resets `last_response_time` to current time

2. **Task Execution Phase**
   - Claude Code processes the user's request
   - No notification system intervention

3. **Claude Response Complete** (< 100ms)
   - Claude Code stops (Stop event triggered)
   - `task-complete.sh` hook executes
   - Updates `last_response_time` to current time
   - Checks if daemon is running, starts if needed
   - Daemon begins monitoring this task

4. **Background Monitoring** (continuous)
   - Daemon checks all state files every 15 seconds
   - Calculates: `silence_duration = now - last_response_time`
   - If `silence_duration >= threshold` AND `!notification_sent`:
     - Reads task context (start_time, prompt)
     - Calculates total task duration
     - Sends notification via enabled channels
     - Marks `notification_sent = true` in state file

5. **User Provides Input** (< 50ms)
   - User submits new prompt
   - `user-input-detected.sh` resets `last_response_time`
   - Clears `notification_sent` flag
   - Timer resets, monitoring continues

6. **Cleanup**
   - State files older than 24 hours automatically deleted
   - Daemon exits after 1 hour of no active tasks

**Key Design Principles:**

- **State-Based**: Uses persistent state files instead of in-memory timers
- **Single Daemon**: One background process monitors all tasks efficiently
- **Non-blocking**: Notification failures never interrupt main workflow
- **Auto-Reset**: Timer automatically resets on user input
- **Resource-Efficient**: Daemon auto-exits when idle
- **Logging**: All activities logged for debugging

## Performance Characteristics

- **Hook Overhead**: < 100ms total for all hooks per interaction
- **State File I/O**: Single JSON file per task, automatic cleanup after 24h
- **Daemon Resource Usage**: ~2-5 MB memory, negligible CPU (<1%)
- **Check Interval**: 1 second (configurable)
- **Parallel Delivery**: Multiple notification channels execute concurrently
- **Memory Usage**: Negligible, state stored in filesystem
- **Network**: Only DingTalk/Lark require network (failures don't block)
- **Scalability**: Can handle 100+ concurrent tasks efficiently

## Security Considerations

- **Webhook Security**: Webhook URLs stored in local config file with 600 permissions
- **DingTalk Signature**: Optional HMAC-SHA256 signature verification supported
- **Message Content**: Notifications include user prompts - ensure config file is protected
- **Log Privacy**: Webhook URLs partially masked in logs for security
- **File Permissions**: Configuration and state files created with restrictive permissions
- **State File Privacy**: User prompts stored in state files with 600 permissions
- **Daemon Process**: Runs with user permissions, no elevated privileges required

## Configuration Examples

### Minimal Configuration (Mac notifications only)

```json
{
  "enabled": true,
  "silence_duration": 15,
  "state": {
    "directory": "~/.claude/scripts/system-notify/state/"
  },
  "channels": {
    "mac": {
      "enabled": true
    }
  }
}
```

### Full Configuration (all channels enabled)

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
      "enabled": true,
      "webhook": "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN",
      "secret": "YOUR_SECRET"
    },
    "lark": {
      "enabled": true,
      "webhook": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_TOKEN"
    }
  },
  "message": {
    "includePrompt": true,
    "includeDuration": true,
    "includeTimestamp": true,
    "maxPromptLength": 150
  }
}
```

### Development Configuration (debug enabled)

```bash
export CLAUDE_NOTIFICATION_DEBUG=1
export CLAUDE_NOTIFICATION_THRESHOLD=5  # Lower threshold for testing
```

## Uninstallation

To completely remove the notification system:

```bash
# Remove notification system directory
rm -rf ~/.claude/scripts/system-notify

# Remove hooks from ~/.claude/settings.json
# (manually edit to remove the hooks configuration)

# Kill daemon if running
pkill -f task-monitor-daemon.sh
```

Then remove the hooks configuration from `~/.claude/settings.json`.

## File Inventory

### Installation Files

Located in the plugin directory `plugins/notification-system/skills/notification-system/scripts/`:

- `install.sh` - Installation and setup script
- `task-start.sh` - Task start hook
- `user-input-detected.sh` - User input detection hook
- `task-complete.sh` - Task completion hook
- `task-monitor-daemon.sh` - Background monitoring daemon
- `utils.sh` - Utility functions
- `test-task-start.sh` - Test suite for task start
- `test-task-complete.sh` - Test suite for task complete
- `test-user-input-detected.sh` - Test suite for user input
- `test-task-monitor-daemon.sh` - Test suite for daemon
- `notifiers/mac.sh` - Mac notifications
- `notifiers/dingtalk.sh` - DingTalk notifications
- `notifiers/lark.sh` - Lark notifications
- `notification-config.json` - Default configuration template

### Documentation

- `SKILL.md` - This comprehensive skill documentation
- `README.md` - Source project README

## Getting Help

### Resources

1. **Check Logs**:
   - Main: `tail -f ~/.claude/scripts/system-notify/logs/notification.log`
   - Daemon: `tail -f ~/.claude/scripts/system-notify/logs/daemon.log`
2. **Run Test Scripts**: See test scripts listed above
3. **Enable Debug Mode**: `export CLAUDE_NOTIFICATION_DEBUG=1`
4. **Check Daemon Status**: `ps aux | grep task-monitor-daemon`
5. **Verify Configuration**: Validate JSON syntax in `~/.claude/scripts/system-notify/notification-config.json`
6. **Check State Files**: `ls -la ~/.claude/scripts/system-notify/state/`

### Support Steps

If you encounter issues:

1. Check the Troubleshooting section above
2. Enable debug logging
3. Review the notification.log and daemon.log files
4. Run the test scripts to identify failing components
5. Verify your configuration file syntax
6. Test webhook URLs manually with curl
7. Check system permissions and directory structure
8. Verify daemon is running and state files are being created

## Version History

### v2.0.0 (2026-01-30)

**Breaking Changes:**
- Changed notification trigger from "task completion" to "user silence detection"
- Removed `notify.sh` script (functionality integrated into daemon)
- State files moved from `tmp/` to `state/` directory
- Configuration key changed from `timeThreshold` to `silence_duration`

**New Features:**
- Background daemon for continuous monitoring (`task-monitor-daemon.sh`)
- User input detection hook (`user-input-detected.sh`)
- Automatic timer reset on user input
- State-based architecture with persistent state files
- Support for multiple concurrent tasks
- Automatic cleanup of old state files (24h)
- Daemon auto-exits when idle (1h)

**Improvements:**
- More efficient resource usage with single daemon process
- Better separation of concerns between hooks
- Enhanced logging with separate daemon log
- Comprehensive test suite with dedicated test scripts

### v1.0.2 (2026-01-29)

- Directory structure reorganization
- Consolidated all runtime files to `~/.claude/scripts/system-notify/`

### v1.0.1 (2026-01-29)

- Fixed hook payload handling
- Added transcript-based notification summaries

### v1.0.0 (2026-01-28)

- Initial release
- Mac system notification support
- DingTalk and Lark bot integration
- Configurable time thresholds
- Complete logging system
