#!/bin/bash

# Package a skill into a Claude Code plugin
# Usage: package-plugin.sh <skill-name> [version]

set -e

SKILL_NAME="$1"
VERSION="${2:-1.0.0}"
SKILLS_DIR="$HOME/.claude/skills"
MARKETPLACE_DIR="/tmp/ht-agent-plugin-market"
MARKETPLACE_REPO="https://gitlab.mokahr.com/devops/ht-agent-plugin-market.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show usage
usage() {
    echo "Usage: $0 <skill-name> [version]"
    echo ""
    echo "Available skills:"
    ls -1 "$SKILLS_DIR" 2>/dev/null | grep -v "^\." | while read skill; do
        if [ -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
            desc=$(grep -m1 "^description:" "$SKILLS_DIR/$skill/SKILL.md" 2>/dev/null | sed 's/description: //' || echo "No description")
            echo "  - $skill: $desc"
        fi
    done
    exit 1
}

# Check arguments
if [ -z "$SKILL_NAME" ]; then
    usage
fi

# Check skill exists
SKILL_PATH="$SKILLS_DIR/$SKILL_NAME"
if [ ! -d "$SKILL_PATH" ]; then
    log_error "Skill not found: $SKILL_NAME"
    echo "Available skills:"
    ls -1 "$SKILLS_DIR" 2>/dev/null | grep -v "^\."
    exit 1
fi

if [ ! -f "$SKILL_PATH/SKILL.md" ]; then
    log_error "SKILL.md not found in $SKILL_PATH"
    exit 1
fi

log_info "Packaging skill: $SKILL_NAME (version $VERSION)"

# Ensure marketplace repo exists
if [ ! -d "$MARKETPLACE_DIR/.git" ]; then
    log_info "Cloning marketplace repository..."
    rm -rf "$MARKETPLACE_DIR"
    git clone "$MARKETPLACE_REPO" "$MARKETPLACE_DIR"
fi

# Pull latest changes
log_info "Pulling latest changes..."
cd "$MARKETPLACE_DIR"
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true

# Extract skill metadata from SKILL.md
SKILL_DESC=$(grep -m1 "^description:" "$SKILL_PATH/SKILL.md" 2>/dev/null | sed 's/description: //' || echo "A Claude Code plugin")
# Remove Chinese quotes that break JSON parsing
SKILL_DESC=$(echo "$SKILL_DESC" | sed 's/[""]/\"/g' | sed 's/\"//g')

# Create plugin directory structure
PLUGIN_DIR="$MARKETPLACE_DIR/plugins/$SKILL_NAME"
log_info "Creating plugin directory: $PLUGIN_DIR"

rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/.claude-plugin"
mkdir -p "$PLUGIN_DIR/skills"

# Create plugin.json
log_info "Generating plugin.json..."
cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" << EOF
{
  "name": "$SKILL_NAME",
  "description": "$SKILL_DESC",
  "version": "$VERSION"
}
EOF

# Copy skill files (excluding sensitive files)
log_info "Copying skill files..."
cp -r "$SKILL_PATH" "$PLUGIN_DIR/skills/"

# Remove potential sensitive files
rm -rf "$PLUGIN_DIR/skills/$SKILL_NAME/.claude" 2>/dev/null || true
rm -f "$PLUGIN_DIR/skills/$SKILL_NAME/.DS_Store" 2>/dev/null || true

# Check for potential secrets
log_info "Checking for potential secrets..."
SECRETS_FOUND=0
if grep -rE "(password|secret|token|api_key|apikey|auth)" "$PLUGIN_DIR/skills/" --include="*.md" --include="*.json" --include="*.sh" --include="*.py" 2>/dev/null | grep -v "^Binary"; then
    log_warn "⚠️  Potential secrets found in skill files!"
    log_warn "Please review and remove sensitive data before pushing."
    SECRETS_FOUND=1
fi

# Create plugin README
log_info "Creating plugin README..."
cat > "$PLUGIN_DIR/README.md" << EOF
# $SKILL_NAME

$SKILL_DESC

## Installation

\`\`\`bash
/plugin install $SKILL_NAME from MallocGad/ht-agent-plugin-market
\`\`\`

## Version

$VERSION

## Usage

See the skill documentation in \`skills/$SKILL_NAME/SKILL.md\`
EOF

# Update marketplace.json
log_info "Updating marketplace.json..."
MARKETPLACE_JSON="$MARKETPLACE_DIR/.claude-plugin/marketplace.json"

# Ensure marketplace.json exists
if [ ! -f "$MARKETPLACE_JSON" ]; then
    mkdir -p "$MARKETPLACE_DIR/.claude-plugin"
    cat > "$MARKETPLACE_JSON" << EOF
{
  "name": "ht-agent-plugin-market",
  "owner": {
    "name": "ht Agent Team",
    "email": "htao0329@gmail.com"
  },
  "plugins": []
}
EOF
fi

# Add plugin to marketplace.json using Python (more reliable JSON handling)
python3 << EOF
import json
import os

marketplace_path = "$MARKETPLACE_JSON"
plugin_name = "$SKILL_NAME"
plugin_desc = """$SKILL_DESC"""
plugin_version = "$VERSION"

with open(marketplace_path, 'r') as f:
    data = json.load(f)

# Remove existing entry if present
data['plugins'] = [p for p in data.get('plugins', []) if p.get('name') != plugin_name]

# Add new entry with correct structure
data['plugins'].append({
    "name": plugin_name,
    "source": f"./plugins/{plugin_name}",
    "description": plugin_desc,
    "version": plugin_version,
    "author": {
        "name": "ht Agent Team"
    }
})

with open(marketplace_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Added {plugin_name} to marketplace.json")
EOF

# Update main README
log_info "Updating main README..."
python3 << EOF
import os
import json

marketplace_dir = "$MARKETPLACE_DIR"
marketplace_json = "$MARKETPLACE_JSON"

with open(marketplace_json, 'r') as f:
    data = json.load(f)

plugins = data.get('plugins', [])

readme_content = """# ht Agent Plugin Marketplace

Custom Claude Code plugins for ht team.

## Usage

Add this marketplace to Claude Code:

\`\`\`bash
/plugin marketplace add MallocGad/ht-agent-plugin-market
\`\`\`

Or with full GitLab URL:

\`\`\`bash
/plugin marketplace add https://github.com/MallocGad/ht-agent-plugin-market.git
\`\`\`

Then browse and install plugins using \`/plugin\` menu.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
"""

for plugin in plugins:
    readme_content += f"| {plugin['name']} | {plugin['description'][:60]}{'...' if len(plugin['description']) > 60 else ''} | {plugin['version']} |\n"

if not plugins:
    readme_content += "| (empty) | No plugins yet | - |\n"

readme_content += """
## Contributing

Use the \`/package-plugin\` skill to package and publish new plugins.
"""

with open(os.path.join(marketplace_dir, 'README.md'), 'w') as f:
    f.write(readme_content)

print("Updated README.md")
EOF

# Show status
echo ""
log_success "Plugin packaged successfully!"
echo ""
echo "Plugin location: $PLUGIN_DIR"
echo ""
echo "Files created:"
find "$PLUGIN_DIR" -type f | sed 's|'"$MARKETPLACE_DIR"'/||'
echo ""

# Show git status
echo "Git status:"
cd "$MARKETPLACE_DIR"
git status --short

echo ""
if [ $SECRETS_FOUND -eq 1 ]; then
    log_warn "⚠️  Review the files above for secrets before pushing!"
    echo ""
fi

echo "To publish, run:"
echo "  cd $MARKETPLACE_DIR"
echo "  git add ."
echo "  git commit -m \"Add plugin: $SKILL_NAME v$VERSION\""
echo "  git push origin main"
