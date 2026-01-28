---
name: notification-system
description: Claude Code 长任务完成通知系统。在任务运行超过阈值时自动发送通知，支持 Mac 系统通知、钉钉和飞书 IM 通知。
---

# Claude Code Notification System Skill

## Overview

The notification-system skill automatically sends completion notifications when Claude Code tasks exceed a configurable time threshold. This is especially useful when working on long-running tasks where you switch to other work and need timely alerts.

### Key Features

- **🔔 Automatic Notifications**: Automatically sends notifications when task execution exceeds the time threshold
- **🖥️ Mac System Notifications**: Native macOS notifications with optional sound alerts
- **💬 IM Notifications**: Support for DingTalk (钉钉) and Lark (飞书) bot notifications
- **⚙️ Flexible Configuration**: Customizable time thresholds, notification channels, and message formats
- **📊 Complete Logging**: All notification activities are logged for debugging and auditing
- **🔄 Graceful Degradation**: Notification failures never block the main task flow, system continues normally
- **⚡ Performance**: Hook execution time < 100ms, no impact on main workflow

## Quick Start

### 1. Environment Variables

Set up these environment variables to control notification behavior:

```bash
# Enable/disable the entire notification system (default: 1)
export CLAUDE_NOTIFICATION_ENABLED=1

# Enable debug logging for troubleshooting
export CLAUDE_NOTIFICATION_DEBUG=0

# Override time threshold in seconds (optional)
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
    "hooks": [{
      "type": "command",
      "command": "~/.claude/scripts/task-start.sh",
      "timeout": 5
    }]
  }],
  "Stop": [{
    "hooks": [{
      "type": "command",
      "command": "~/.claude/scripts/task-complete.sh",
      "timeout": 10
    }]
  }]
}
```

The `UserPromptSubmit` hook captures the start time and initial prompt, while the `Stop` hook evaluates whether to send notifications when the task completes.

### 4. Testing Notifications

Verify that notifications work correctly with the test script:

```bash
~/.claude/scripts/test-notification.sh
```

This will send a test notification through each enabled channel and display success/failure status.

## Core Operations

### Mac System Notifications Setup

Mac notifications are the simplest channel to set up and work out of the box on macOS systems.

**Configuration in `~/.claude/notification-config.json`:**

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
│   Claude Code Task Complete         │
│   Duration: 2min 15sec              │
│                                     │
│   Implementing notification...      │
│   2026-01-26 14:30:45              │
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
🎉 Claude Code Task Complete

Task Description: Implementing notification functionality for Claude Code...

Duration: 2min 15sec

Completion Time: 2026-01-26 14:30:45
```

## Configuration Reference

### Complete Configuration File

A complete `~/.claude/notification-config.json` with all options:

```json
{
  "enabled": true,
  "timeThreshold": 15,
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
| `timeThreshold` | number | `15` | Time threshold in seconds before triggering notification | `30` |

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
| `CLAUDE_NOTIFICATION_THRESHOLD` | number | Override the `timeThreshold` in seconds |
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
5. Check logs: `tail -f ~/.claude/logs/notification.log`

#### Issue: DingTalk/Lark notifications not received

**Symptoms:** No message appears in IM, or connection timeout errors

**Solutions:**
1. Verify that `channels.dingtalk.enabled` or `channels.lark.enabled` is `true`
2. Double-check the webhook URL is complete and correct
3. Test webhook manually with curl (see Core Operations section)
4. Verify network connectivity to external services
5. Check logs for detailed error messages
6. For DingTalk, verify signature secret if configured

#### Issue: Task completed but no notification

**Symptoms:** Task runs longer than threshold, but no notification received

**Solutions:**
1. Verify `enabled` is `true` and `timeThreshold` is appropriate
2. Confirm at least one notification channel is enabled
3. Check that task duration actually exceeds threshold: `cat ~/.claude/logs/notification.log`
4. Ensure hooks are properly configured in `~/.claude/settings.json`
5. Run test script to verify channels work: `~/.claude/scripts/test-notification.sh`

#### Issue: Script permission errors

**Symptoms:** "Permission denied" when running scripts

**Solutions:**
1. Check file permissions: `ls -l ~/.claude/scripts/`
2. Fix permissions: `chmod +x ~/.claude/scripts/**/*.sh`
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
# Watch logs in real-time
tail -f ~/.claude/logs/notification.log

# View recent entries
tail -20 ~/.claude/logs/notification.log

# Search for errors
grep ERROR ~/.claude/logs/notification.log

# View specific date
grep "2026-01-26" ~/.claude/logs/notification.log
```

#### Log File Locations

- **Notification Log**: `~/.claude/logs/notification.log`
- **Temporary State Files**: `~/.claude/tmp/claude-task-*.json` (auto-cleaned)
- **Configuration**: `~/.claude/notification-config.json`

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

#### Run Test Notification Script

Comprehensive test that validates all configured channels:

```bash
~/.claude/scripts/test-notification.sh
```

Output will show success/failure for each enabled channel with detailed error messages if problems occur.

## Script Details

### Directory Structure

```
~/.claude/
├── notification-config.json          # User configuration file
├── settings.json                     # Claude Code settings with hooks
├── scripts/
│   ├── task-start.sh                 # Triggered on UserPromptSubmit event
│   ├── task-complete.sh              # Triggered on Stop event
│   ├── notify.sh                     # Notification dispatcher and coordinator
│   ├── utils.sh                      # Shared utility functions
│   ├── test-notification.sh          # Test script for validation
│   └── notifiers/
│       ├── mac.sh                    # Mac system notification handler
│       ├── dingtalk.sh               # DingTalk notification handler
│       └── lark.sh                   # Lark notification handler
├── logs/
│   └── notification.log              # Complete notification activity log
└── tmp/
    └── claude-task-*.json            # Temporary task state (auto-deleted)
```

### Script Purposes

#### `task-start.sh`
- **Hook Event**: UserPromptSubmit
- **Purpose**: Captures the task start time and initial prompt text
- **Actions**:
  - Records timestamp in JSON format
  - Stores user's prompt for inclusion in notifications
  - Creates temporary state file
- **Execution Time**: < 50ms
- **Side Effects**: Creates `~/.claude/tmp/claude-task-[PID].json`

#### `task-complete.sh`
- **Hook Event**: Stop
- **Purpose**: Evaluates whether to trigger notifications
- **Actions**:
  - Calculates task duration
  - Compares against configured threshold
  - Calls `notify.sh` if threshold exceeded
  - Cleans up temporary files
- **Execution Time**: < 100ms
- **Side Effects**: Modifies/deletes temporary state files, logs activity

#### `notify.sh`
- **Purpose**: Dispatcher that determines which channels to use
- **Actions**:
  - Reads configuration from `notification-config.json`
  - Formats notification message
  - Calls appropriate notifier scripts in parallel
  - Logs results
- **Execution Time**: < 200ms for parallel notifiers
- **Calls**: `notifiers/mac.sh`, `notifiers/dingtalk.sh`, `notifiers/lark.sh`

#### `utils.sh`
- **Purpose**: Shared utility functions used by other scripts
- **Key Functions**:
  - Configuration loading and parsing
  - Time formatting utilities
  - Logging helpers
  - Error handling functions
  - JSON state file management

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

1. **Task Start Phase** (< 50ms)
   - User submits a prompt in Claude Code
   - `task-start.sh` hook executes
   - Captures current timestamp
   - Stores prompt text and task metadata
   - Creates temporary state file: `~/.claude/tmp/claude-task-[PID].json`

2. **Task Execution Phase**
   - Claude Code processes the user's request
   - No notification system intervention

3. **Task Complete Phase** (< 100ms)
   - Claude Code stops (Stop event triggered)
   - `task-complete.sh` hook executes
   - Loads task start information from temp file
   - Calculates elapsed time
   - Compares against configured threshold
   - If elapsed time >= threshold:
     - Calls `notify.sh` with task details
     - `notify.sh` reads configuration
     - `notify.sh` calls enabled notifier scripts in parallel
     - Each notifier sends notification to its respective channel
     - Results logged to `~/.claude/logs/notification.log`
   - Cleans up temporary state file

4. **Notification Delivery**
   - Mac notifier: Uses native system notifications
   - DingTalk notifier: Posts to bot webhook
   - Lark notifier: Posts to bot webhook
   - Failures logged but don't block task

**Key Design Principles:**

- **Non-blocking**: Notification failures never interrupt main workflow
- **Parallel Execution**: Multiple notification channels run simultaneously
- **Quick Completion**: All hooks designed for < 100ms execution
- **Stateless**: Each invocation is independent, no shared state
- **Logging**: All activities logged for debugging

## Performance Characteristics

- **Hook Overhead**: < 100ms total for task-start and task-complete hooks
- **State File I/O**: Single JSON file per task, automatic cleanup
- **Parallel Delivery**: Multiple notification channels execute concurrently
- **Memory Usage**: Negligible, scripts are lightweight
- **Network**: Only DingTalk/Lark require network (failures don't block)

## Security Considerations

- **Webhook Security**: Webhook URLs stored in local config file with 600 permissions
- **DingTalk Signature**: Optional HMAC-SHA256 signature verification supported
- **Message Content**: Notifications exclude sensitive information by design
- **Log Privacy**: Webhook URLs partially masked in logs for security
- **File Permissions**: Configuration file created with restrictive permissions

## Configuration Examples

### Minimal Configuration (Mac notifications only)

```json
{
  "enabled": true,
  "timeThreshold": 15,
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
  "timeThreshold": 15,
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
# Remove scripts directory
rm -rf ~/.claude/scripts

# Remove logs directory
rm -rf ~/.claude/logs

# Remove configuration
rm -f ~/.claude/notification-config.json

# Remove hooks from ~/.claude/settings.json
# (manually edit to remove the hooks configuration)
```

Then remove the hooks configuration from `~/.claude/settings.json`.

## File Inventory

### Installation Files

Located in the plugin directory `plugins/notification-system/scripts/`:

- `install.sh` - Installation and setup script
- `task-start.sh` - Task start hook
- `task-complete.sh` - Task completion hook
- `notify.sh` - Notification dispatcher
- `utils.sh` - Utility functions
- `test-notification.sh` - Test suite
- `notifiers/mac.sh` - Mac notifications
- `notifiers/dingtalk.sh` - DingTalk notifications
- `notifiers/lark.sh` - Lark notifications

### Configuration Files

- `config/notification-config.json` - Default configuration template

### Documentation

- `SKILL.md` - This comprehensive skill documentation
- `README.md` - Source project README

## Getting Help

### Resources

1. **Check Logs**: `tail -f ~/.claude/logs/notification.log`
2. **Run Test Script**: `~/.claude/scripts/test-notification.sh`
3. **Enable Debug Mode**: `export CLAUDE_NOTIFICATION_DEBUG=1`
4. **Review Source Scripts**: Check the script contents to understand behavior
5. **Verify Configuration**: Validate JSON syntax in `~/.claude/notification-config.json`

### Support Steps

If you encounter issues:

1. Check the Troubleshooting section above
2. Enable debug logging
3. Review the notification.log file
4. Run the test-notification.sh script
5. Verify your configuration file syntax
6. Test webhook URLs manually with curl
7. Check system permissions and directory structure

## Version History

### v1.0.0 (2026-01-26)

- Initial release of Claude Code notification system
- Mac system notification support with sound alerts
- DingTalk bot integration with signature verification
- Lark bot integration with rich formatting
- Comprehensive configuration management
- Complete logging and debugging support
- Test suite for validation
- Full documentation and guides
