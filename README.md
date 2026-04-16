# claude-rules

Global rules for Claude Code sessions. Synced to `~/.claude/` on every machine.

## Setup (run once per machine)

```bash
# Clone into your .claude directory
cd ~/.claude
git clone https://github.com/dthomas-dev/claude-rules.git _rules_repo

# Symlink so Claude Code picks it up automatically
# Windows (Git Bash):
ln -s "$(pwd)/_rules_repo/CLAUDE.md" "$(pwd)/CLAUDE.md"

# Mac/Linux:
ln -s ~/.claude/_rules_repo/CLAUDE.md ~/.claude/CLAUDE.md
```

## Update rules on all machines

Edit `CLAUDE.md` in this repo and push. Then on each machine:

```bash
cd ~/.claude/_rules_repo && git pull
```

The symlink means `~/.claude/CLAUDE.md` stays current automatically.

## What this does

`~/.claude/CLAUDE.md` is loaded at the start of every Claude Code session,
regardless of which project you're in. These are global behavioral rules.

Project-specific rules still go in each project's own `CLAUDE.md`.
