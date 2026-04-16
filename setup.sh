#!/usr/bin/env bash
#
# One-time setup: run this on any new machine.
#   curl -sL https://raw.githubusercontent.com/dthomas-dev/claude-rules/main/setup.sh | bash
#
# Or if already cloned:
#   bash ~/.claude/_rules_repo/setup.sh
#

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
REPO_URL="https://github.com/dthomas-dev/claude-rules.git"
REPO_DIR="$CLAUDE_DIR/_rules_repo"

echo "Setting up Claude Code global rules..."

# Clone if not already present
if [ ! -d "$REPO_DIR" ]; then
  echo "  Cloning rules repo..."
  git clone "$REPO_URL" "$REPO_DIR"
else
  echo "  Rules repo already cloned, pulling latest..."
  cd "$REPO_DIR" && git pull
fi

cd "$CLAUDE_DIR"

# Symlink CLAUDE.md
rm -f CLAUDE.md
ln -s "_rules_repo/CLAUDE.md" "CLAUDE.md"
echo "  Linked CLAUDE.md"

# Symlink settings.json
rm -f settings.json
ln -s "_rules_repo/settings.json" "settings.json"
echo "  Linked settings.json"

# Symlink hooks
mkdir -p hooks
for f in _rules_repo/hooks/*.sh; do
  name=$(basename "$f")
  ln -sf "../_rules_repo/hooks/$name" "hooks/$name"
done
chmod +x hooks/*.sh 2>/dev/null || true
echo "  Linked hooks"

# Symlink skills
mkdir -p skills/verify
ln -sf "../../_rules_repo/skills/verify/SKILL.md" "skills/verify/SKILL.md"
echo "  Linked /verify skill"

echo ""
echo "Done. Rules, hooks, and skills are active for all Claude Code sessions."
echo "To update later: cd ~/.claude/_rules_repo && git pull"
