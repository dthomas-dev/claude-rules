#!/usr/bin/env bash
#
# PreToolUse hook (Bash): block git commit/push when staged files have problems.
#
# Fires when a Bash command contains "git commit" or "git push".
# Checks:
#   1. Staged .py files for stub markers (# TODO, # Future:, # STUB, etc.)
#   2. Staged .py files for syntax errors (python -m py_compile)
#   3. Recent CI workflow status (warn only, not block)
#
# Exit codes:
#   0 — allow (clean, or not a git commit/push command)
#   2 — BLOCK; stderr fed back to Claude
#

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Only fires on Bash tool
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Only fires on git commit or git push
if ! echo "$COMMAND" | grep -qE "git commit|git push"; then
  exit 0
fi

PROBLEMS=""
WARNINGS=""

# ── Check 1: Stub markers in staged .py files ──
STAGED_PY=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '\.py$' || echo "")

if [ -n "$STAGED_PY" ]; then
  STUB_HITS=""
  while IFS= read -r pyfile; do
    [ -f "$pyfile" ] || continue
    # Grep for stub markers, excluding lines that are documenting the rule itself
    HITS=$(grep -nE '# (TODO|FIXME|STUB|HACK|XXX)|# Future:|raise NotImplementedError' "$pyfile" 2>/dev/null \
      | grep -v "grep.*TODO\|grep.*STUB\|grep.*Future" \
      | grep -v "search for stubs" \
      | grep -v "PATTERNS=" \
      || echo "")
    if [ -n "$HITS" ]; then
      STUB_HITS="${STUB_HITS}
  ${pyfile}:
$(echo "$HITS" | sed 's/^/    /')"
    fi
  done <<< "$STAGED_PY"

  if [ -n "$STUB_HITS" ]; then
    PROBLEMS="${PROBLEMS}

STUB MARKERS FOUND in staged files:
${STUB_HITS}

Remove these markers or replace with real implementations before committing."
  fi

  # ── Check 2: Syntax errors in staged .py files ──
  SYNTAX_ERRORS=""
  while IFS= read -r pyfile; do
    [ -f "$pyfile" ] || continue
    ERR=$(python -m py_compile "$pyfile" 2>&1 || true)
    if [ -n "$ERR" ]; then
      SYNTAX_ERRORS="${SYNTAX_ERRORS}
  ${pyfile}: ${ERR}"
    fi
  done <<< "$STAGED_PY"

  if [ -n "$SYNTAX_ERRORS" ]; then
    PROBLEMS="${PROBLEMS}

SYNTAX ERRORS in staged files:
${SYNTAX_ERRORS}"
  fi
fi

# ── Check 3: Failing CI (warn only) ──
if command -v gh >/dev/null 2>&1; then
  RECENT_FAILURES=$(gh run list --limit=5 --json conclusion,name 2>/dev/null \
    | jq -r '.[] | select(.conclusion=="failure") | .name' 2>/dev/null \
    | head -3 || echo "")
  if [ -n "$RECENT_FAILURES" ]; then
    WARNINGS="${WARNINGS}

WARNING — Recent CI failures detected:
$(echo "$RECENT_FAILURES" | sed 's/^/  - /')
These may or may not be related to your changes. Check before pushing."
  fi
fi

# ── Verdict ──
if [ -n "$PROBLEMS" ]; then
  cat >&2 <<EOF
PRE-COMMIT GATE BLOCKED THIS COMMIT.

The following problems were found in staged files:
${PROBLEMS}
${WARNINGS}

Fix these issues before committing. The quadruple-check rule requires
every commit to be free of stubs and syntax errors.
EOF
  exit 2
fi

# Warnings only — allow but inform
if [ -n "$WARNINGS" ]; then
  echo "${WARNINGS}" >&2
  exit 1  # Non-blocking warning
fi

exit 0
