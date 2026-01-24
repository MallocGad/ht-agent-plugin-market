---
name: package-plugin
description: Package a skill into a Claude Code plugin and publish to marketplace. Use when the user wants to distribute or share a skill as a plugin.
---

# Package Plugin Skill

Package existing skills into Claude Code plugins and publish them to your marketplace.

## Marketplace Configuration

```
Repository: https://github.com/MallocGad/ht-agent-plugin-market.git
Local Path: /tmp/ht-agent-plugin-market
```

## Usage

When the user wants to package a skill:

### Step 1: List Available Skills

```bash
ls -la ~/.claude/skills/
```

### Step 2: Package the Skill

Use the packaging script:

```bash
~/.claude/skills/package-plugin/scripts/package-plugin.sh <skill-name> [version]
```

Example:
```bash
~/.claude/skills/package-plugin/scripts/package-plugin.sh jira-query 1.0.0
```

### Step 3: Review and Push

After packaging, the script will:
1. Create plugin directory structure in the marketplace repo
2. Copy skill files to the plugin
3. Generate plugin.json manifest
4. Update marketplace.json
5. Show git status for review

Then push to remote:
```bash
cd /tmp/ht-agent-plugin-market && git add . && git commit -m "Add plugin: <name>" && git push origin main
```

## Plugin Structure Generated

```
/tmp/ht-agent-plugin-market/
├── .claude-plugin/
│   └── marketplace.json       # Updated with new plugin
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json    # Plugin manifest
│       ├── skills/
│       │   └── <skill-name>/
│       │       ├── SKILL.md
│       │       └── scripts/
│       └── README.md
└── README.md
```

## Manual Packaging (Alternative)

If you need more control, manually create the plugin structure:

### 1. Create plugin directory
```bash
PLUGIN_NAME="my-plugin"
MARKETPLACE="/tmp/ht-agent-plugin-market"
mkdir -p "$MARKETPLACE/plugins/$PLUGIN_NAME/.claude-plugin"
mkdir -p "$MARKETPLACE/plugins/$PLUGIN_NAME/skills"
```

### 2. Create plugin.json
```json
{
  "name": "my-plugin",
  "description": "Description of your plugin",
  "version": "1.0.0"
}
```

### 3. Copy skill files
```bash
cp -r ~/.claude/skills/my-skill "$MARKETPLACE/plugins/$PLUGIN_NAME/skills/"
```

### 4. Update marketplace.json
Add your plugin to the plugins array in `.claude-plugin/marketplace.json`

## Notes

- Skills with sensitive data (passwords, tokens) should have those removed before packaging
- The script will warn about potential secrets in skill files
- Always review the generated plugin before pushing
