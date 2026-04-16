#!/usr/bin/env bash
#
# Stop hook: block completion claims that lack verification evidence.
#
# Scans the last assistant message for completion language ("done", "complete",
# "shipped", "fixed", "all working", "no stubs remain", etc.). If found, checks
# the transcript for evidence that verification actually happened:
#   - Code claims → need a Bash call with python/pytest/node in recent tool uses
#   - Infrastructure claims → need a Bash call with gh/curl/gcloud/query commands
#   - "No stubs" claims → need a Grep call with TODO/STUB/Future patterns
#   - "CI passing" claims → need a Bash call with gh run list/view
#
# Exit codes:
#   0 — allow (no completion language, or evidence found)
#   2 — BLOCK; stderr fed back to Claude as system reminder
#

set -euo pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path' 2>/dev/null || echo "")
TRANSCRIPT="${TRANSCRIPT/#\~/$HOME}"

if [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Extract the LAST assistant text message.
LAST_ASSISTANT=$(tac "$TRANSCRIPT" 2>/dev/null | jq -rR '
  fromjson? | select(.type=="assistant") |
  (.message.content // []) |
  if type == "array" then
    map(select(.type=="text") | .text) | join("\n")
  else
    .
  end
' 2>/dev/null | head -1)

if [ -z "$LAST_ASSISTANT" ]; then
  exit 0
fi

# Also scan recent file edits (same pattern as no-settle-lint).
RECENT_EDITS=$(tac "$TRANSCRIPT" 2>/dev/null | jq -rR '
  fromjson? | select(.type=="assistant") |
  (.message.content // []) |
  if type == "array" then
    map(select(.type=="tool_use" and (.name=="Edit" or .name=="Write" or .name=="NotebookEdit"))
        | (.input.new_string // .input.content // .input.new_source // ""))
    | join("\n")
  else
    ""
  end
' 2>/dev/null | head -2000)

COMBINED="$LAST_ASSISTANT
${RECENT_EDITS}"

# Strip fenced code blocks to avoid false positives on quoted code.
STRIPPED=$(echo "$COMBINED" | awk '
  BEGIN { in_fence=0 }
  /^```/ { in_fence = !in_fence; next }
  in_fence == 0 { print }
' | sed -E 's/`[^`]+`//g')

# ── Detect completion claims ──────────────────────────────────────────
# These are phrases that signal "I'm declaring this work finished."
# Keep tight to avoid false positives on progress updates.
COMPLETION_PATTERNS='(^|\W)(this is done|that.s done|all done|everything.s done|task(s)? (is |are )?complete[d]?|fix(es)? (is |are )?(in place|done|complete|shipped|live)|shipped|fully (complete|operational|working|implemented)|no stubs remain|all .* passing|all checks pass|everything (is )?(working|fixed|live|operational)|phase .* (is )?complete|successfully (built|deployed|shipped|fixed|implemented))(\W|$)'

# grep -c returns count; exit code 1 = no match (not an error).
# Capture count only, suppress the fallback duplication.
if echo "$STRIPPED" | grep -iqE "$COMPLETION_PATTERNS"; then
  HAS_COMPLETION=1
else
  HAS_COMPLETION=0
fi

if [ "$HAS_COMPLETION" = "0" ]; then
  exit 0
fi

# ── Completion language detected — now check for verification evidence ──
# Look at the last 40 transcript entries for tool uses that constitute evidence.

RECENT_TOOLS=$(tail -200 "$TRANSCRIPT" 2>/dev/null | jq -rR '
  fromjson? | select(.type=="assistant") |
  (.message.content // []) |
  if type == "array" then
    map(select(.type=="tool_use") | "\(.name)::\(.input | tostring)")
    | .[]
  else
    empty
  end
' 2>/dev/null | tail -40)

MISSING=""

# Check 1: Code execution evidence (python, pytest, node, npm test)
HAS_CODE_RUN=$(echo "$RECENT_TOOLS" | grep -iE "^Bash::.*(python |pytest|node |npm test|bun test)" || echo "")

# Check 2: Infrastructure verification (gh run, curl, gcloud, BigQuery)
HAS_INFRA_CHECK=$(echo "$RECENT_TOOLS" | grep -iE "^Bash::.*(gh run (view|list)|curl |gcloud |bq |bigquery)" || echo "")

# Check 3: Stub grep evidence
HAS_STUB_GREP=$(echo "$RECENT_TOOLS" | grep -iE "^(Grep|Bash)::.*(TODO|STUB|Future:|NotImplementedError)" || echo "")

# Check 4: CI status check
HAS_CI_CHECK=$(echo "$RECENT_TOOLS" | grep -iE "^Bash::.*(gh run list|gh run view|gh workflow)" || echo "")

# Determine which checks are needed based on what was claimed.
CLAIM_LOWER=$(echo "$STRIPPED" | tr '[:upper:]' '[:lower:]')

if echo "$CLAIM_LOWER" | grep -qE "no stubs|no todo|stub.free|clean"; then
  if [ -z "$HAS_STUB_GREP" ]; then
    MISSING="${MISSING}
  - Claimed 'no stubs' but no grep for TODO/STUB/Future found in recent tool uses"
  fi
fi

if echo "$CLAIM_LOWER" | grep -qE "ci (is )?pass|all.*(passing|green)|workflow.*(pass|success)"; then
  if [ -z "$HAS_CI_CHECK" ]; then
    MISSING="${MISSING}
  - Claimed CI is passing but no 'gh run list/view' found in recent tool uses"
  fi
fi

if echo "$CLAIM_LOWER" | grep -qE "deploy|provisioned|configured|enabled|set up|bigquery|export"; then
  if [ -z "$HAS_INFRA_CHECK" ]; then
    MISSING="${MISSING}
  - Claimed infrastructure is set up but no verification command (gh run view, curl, gcloud) found"
  fi
fi

if echo "$CLAIM_LOWER" | grep -qE "built|implemented|working|operational|runs|execut"; then
  if [ -z "$HAS_CODE_RUN" ] && [ -z "$HAS_INFRA_CHECK" ]; then
    MISSING="${MISSING}
  - Claimed code works but no execution test (python, pytest, node) or infra check found"
  fi
fi

# If we couldn't identify a specific unverified claim, do a general check:
# ANY completion claim needs SOME evidence of verification.
if [ -z "$MISSING" ]; then
  ALL_EVIDENCE="${HAS_CODE_RUN}${HAS_INFRA_CHECK}${HAS_STUB_GREP}${HAS_CI_CHECK}"
  if [ -z "$ALL_EVIDENCE" ]; then
    MISSING="
  - Completion claimed but NO verification evidence found in recent tool uses (no code run, no infra check, no stub grep, no CI check)"
  fi
fi

if [ -z "$MISSING" ]; then
  exit 0
fi

# ── Block ──
cat >&2 <<EOF
VERIFY-BEFORE-DONE HOOK BLOCKED THIS RESPONSE.

Completion language was detected in your response, but verification evidence
is missing from the transcript. Per the quadruple-check rules, every
completion claim must be backed by evidence that the work was actually
verified — not just coded.

Missing verification:
$MISSING

Required action:
1. Run the verification step you skipped (execute the code, check the
   infrastructure, grep for stubs, check CI status).
2. Confirm the results in your response.
3. THEN you can claim completion.

Do NOT remove the completion language and re-send — actually do the
verification first.
EOF

exit 2
