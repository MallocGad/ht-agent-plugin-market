---
name: notification-system-lite
description: Lightweight idle notification system for Claude Code based on built-in idle_prompt events
---

# notification-system-lite

Lightweight notification system that alerts you when Claude Code has been idle (waiting for user input) for a period of time.

## What it does

This skill automatically sends notifications when you haven't responded to Claude after it completes a response. Unlike the full `notification-system` plugin, this lite version:

- **No background processes** - Uses Claude Code's built-in idle detection
- **Zero maintenance** - No daemon to manage
- **Simple architecture** - Just two hook scripts
- **Fixed threshold** - Idle time controlled by Claude Code (approximately 30-60 seconds)

## How it works

1. **Records task context** when you submit a prompt (via UserPromptSubmit hook)
2. **Waits for Claude Code** to detect idle state (built-in idle_prompt event)
3. **Sends notification** with task summary, total duration, and idle time
4. **Prevents duplicates** by marking notifications as sent

## Notification channels

- **macOS System Notifications** - Native notifications with sound
- **DingTalk** - Webhook notifications to DingTalk groups
- **Lark (Feishu)** - Webhook notifications to Lark groups

## Configuration

Edit `~/.claude/scripts/notification-lite/notification-config.json`:

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
      "webhook": "https://oapi.dingtalk.com/robot/send?access_token=...",
      "secret": "SEC..."
    },
    "lark": {
      "enabled": false,
      "webhook": "https://open.feishu.cn/open-apis/bot/v2/hook/..."
    }
  }
}
```

## When to use

**Use notification-system-lite if:**
- You want zero maintenance and no background processes
- 30-60 second idle threshold is acceptable
- You prefer simplicity over flexibility

**Use notification-system (full version) if:**
- You need custom idle thresholds (< 30 seconds)
- You want precise control over notification timing
- You need configurable check intervals

## Logs

View logs at: `~/.claude/scripts/notification-lite/logs/notification.log`

```bash
tail -f ~/.claude/scripts/notification-lite/logs/notification.log
```

## Troubleshooting

**No notifications?**
1. Check `enabled: true` in config
2. Enable at least one channel (mac/dingtalk/lark)
3. Wait long enough for Claude Code to detect idle (30-60 seconds)
4. Check logs for errors

**State files?**
- Located at: `~/.claude/scripts/notification-lite/state/*.state`
- Auto-cleanup after 30 minutes
- Manual cleanup: `rm ~/.claude/scripts/notification-lite/state/*.state`

## Technical details

**Hooks used:**
- `UserPromptSubmit` - Records task start and updates on subsequent inputs
- `Notification(idle_prompt)` - Triggered by Claude Code when idle detected

**State management:**
- Each session has a `.state` file with: session_id, start_time, last_input_time, prompt, notification_sent
- State updates on every user input (resets notification flag)
- Auto-cleanup removes files older than 30 minutes

**Architecture:**
```
UserPromptSubmit → task-start.sh → Create/Update state file
                                          ↓
                                    (User idle)
                                          ↓
Notification(idle_prompt) → send-notification.sh → Read state → Send notifications
```

## Version

1.0.0
