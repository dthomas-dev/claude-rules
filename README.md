# claude-rules

Global rules, hooks, and skills for Claude Code sessions. Synced to `~/.claude/` on every machine.

## What's included

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Global rules loaded every session (quadruple-check, no lesser tools, etc.) |
| `settings.json` | Hook registrations (Stop hooks, PreToolUse hooks) |
| `hooks/verify-before-done.sh` | Blocks completion claims without verification evidence |
| `hooks/pre-commit-gate.sh` | Blocks git commit/push when staged files have stubs or syntax errors |
| `hooks/no-settle-lint.sh` | Blocks deferred/settle language ("acceptable for now", "waiting on volume", etc.) |
| `skills/verify/SKILL.md` | `/verify` slash command — health check checklist before declaring work done |

## Setup (run once per machine)

```bash
cd ~/.claude
git clone https://github.com/dthomas-dev/claude-rules.git _rules_repo

# Symlink CLAUDE.md
ln -s "$(pwd)/_rules_repo/CLAUDE.md" "$(pwd)/CLAUDE.md"

# Symlink settings.json (CAUTION: overwrites existing settings)
# If you have machine-specific settings, merge manually instead
ln -s "$(pwd)/_rules_repo/settings.json" "$(pwd)/settings.json"

# Symlink hooks directory contents
mkdir -p hooks
for f in _rules_repo/hooks/*.sh; do
  ln -sf "$(pwd)/$f" "$(pwd)/hooks/$(basename $f)"
done

# Symlink skills
mkdir -p skills/verify
ln -sf "$(pwd)/_rules_repo/skills/verify/SKILL.md" "$(pwd)/skills/verify/SKILL.md"

# Make hooks executable
chmod +x hooks/*.sh
```

## Update on all machines

```bash
cd ~/.claude/_rules_repo && git pull
```

Symlinks mean everything stays current automatically after pull.

## What each hook does

**verify-before-done.sh** (Stop hook): When Claude's response contains completion language ("done", "shipped", "fully operational", etc.), checks the transcript for evidence that verification actually happened — code execution, CI checks, stub greps, infrastructure queries. Blocks if evidence is missing.

**pre-commit-gate.sh** (PreToolUse on Bash): When Claude runs `git commit` or `git push`, scans staged `.py` files for `# TODO`, `# Future:`, `# STUB`, `raise NotImplementedError`. Blocks the commit if found. Also checks for syntax errors and warns on failing CI.

**no-settle-lint.sh** (Stop hook): Scans Claude's response and recent file edits for deferred/settle language — "acceptable for now", "we'll fix later", "waiting on volume", "recommend checking manually", etc. Blocks and requires either fixing the issue or creating a tracked follow-up.

## Adding new hooks

1. Create the `.sh` file in `hooks/`
2. Register it in `settings.json` under the appropriate event
3. Commit and push
4. On each machine: `cd ~/.claude/_rules_repo && git pull`
