#!/usr/bin/env bash
#
# Stop hook: scan the most recent assistant message for "settle" phrases that
# violate the CLAUDE.md "do it right, don't defer" rule. If any are found,
# block the stop and feed the offending lines back to Claude as a reminder.
#
# Exit codes (Claude Code Stop hook contract):
#   0 — allow the stop normally
#   2 — BLOCK stop; stderr is fed back to the assistant as a system reminder
#
# Whitelisted phrases inside fenced code blocks, quoted user text, or URLs
# are ignored to avoid false positives when quoting docs / past chats.

set -euo pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path' 2>/dev/null || echo "")
TRANSCRIPT="${TRANSCRIPT/#\~/$HOME}"

if [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Extract the LAST assistant text message from the JSONL transcript.
LAST_ASSISTANT=$(tac "$TRANSCRIPT" 2>/dev/null | jq -rR '
  fromjson? | select(.type=="assistant") |
  (.message.content // []) |
  if type == "array" then
    map(select(.type=="text") | .text) | join("\n")
  else
    .
  end
' 2>/dev/null | head -1000)

# ALSO scan the last few file mutations (Edit/Write/NotebookEdit tool inputs).
# Defer-language can hide there too — agent prompts, scripts, docs we just edited.
# Without this, I can codify "recommend manual check" into a prompt file and the hook
# will never see it because file content doesn't appear in my chat output.
RECENT_EDITS=$(tac "$TRANSCRIPT" 2>/dev/null | jq -rR '
  fromjson? | select(.type=="assistant") |
  (.message.content // []) |
  if type == "array" then
    map(select(.type=="tool_use" and (.name=="Edit" or .name=="Write" or .name=="NotebookEdit"))
        | (.input.new_string // .input.content // .input.new_source // ""))
    | join("\n---file-edit-boundary---\n")
  else
    ""
  end
' 2>/dev/null | head -2000)

# Combine assistant text + recent edits for scanning. If both are empty, skip.
COMBINED="$LAST_ASSISTANT
${RECENT_EDITS}"
if [ -z "$(echo "$COMBINED" | tr -d '[:space:]')" ]; then
  exit 0
fi

# Strip fenced code blocks (```) so we don't false-positive on quoted code in chat.
# Inline `code` stripped too. File edits aren't code-fenced so they pass through.
STRIPPED=$(echo "$COMBINED" | awk '
  BEGIN { in_fence=0 }
  /^```/ { in_fence = !in_fence; next }
  in_fence == 0 { print }
' | sed -E 's/`[^`]+`//g')

# Forbidden phrases (case-insensitive). Each line = one phrase.
# Keep this list tight — false positives erode trust in the hook.
read -r -d '' PATTERNS <<'EOF' || true
acceptable for now
acceptable trade-off
good enough for now
we can wait
we'll fix (this|it|that)? later
i'll come back to this
i'll circle back
follow-up later
follow up later
TODO: revisit
TODO follow-up
known limit
known tradeoff
known gap
preexisting gap
for now,
for now -
deferred to (a |the )?(later|future)
later iteration
next iteration
phase 2 fix
will be addressed later
will address later
out of scope (for|right) now
park (this|that) for
revisit (later|next week|tomorrow)
shared unbuilt
unbuilt step
(isn't|is not|not yet) built
separate (unbuilt|future) step
applies to both .* not (a |an )?regression
leave (it|this|that) for
flagged as a memory item for follow-up
working as designed
recommend (a |the )?manual (check|review|verification)
recommend checking manually
manual check before approving
check (it )?manually in
will need to be (checked|verified|done) manually
require[sd]? manual (check|verification|review|intervention)
ask the user to (check|verify|do)
verify (it|this|that) (yourself|in the UI)
waiting on (volume|data|events|traffic)
wait for (volume|data|events) to (accumulate|build|arrive)
needs? time to (accumulate|build|propagate)
(will|should) (show up|populate|appear) once (volume|data|events|traffic)
give it (24|48|72) ?.?(hours?|h|days?|d)? (to|for|before)
once (volume|data|events) (builds?|accumulates?|arrives?)
monitor (this|it) over the next (few|couple of)? ?(days?|weeks?)
check back in (24|48|72) ?.?(hours?|h|days?|d)?
let it bake
EOF

HITS=""
WHILE_IFS_OLD="$IFS"
IFS=$'\n'
for pat in $PATTERNS; do
  pat_trimmed=$(echo "$pat" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [ -z "$pat_trimmed" ] && continue
  # grep -E for extended regex; -i case-insensitive; -n line numbers
  matches=$(echo "$STRIPPED" | grep -inE "$pat_trimmed" || true)
  if [ -n "$matches" ]; then
    HITS="${HITS}
  ▸ Phrase: \"${pat_trimmed}\"
$(echo "$matches" | sed 's/^/      /')"
  fi
done
IFS="$WHILE_IFS_OLD"

if [ -z "$HITS" ]; then
  exit 0
fi

# Found defer/settle language — block the stop and feed back to Claude.
cat >&2 <<EOF
NO-SETTLE LINTER BLOCKED THIS RESPONSE.

CLAUDE.md says: do not defer fixes, do not say something is "acceptable for now",
do not punt to a later iteration. The following lines in your draft response
violate that rule:
$HITS

Required action:
1. Either FIX the thing you were about to defer (and remove the deferring language), OR
2. If it genuinely cannot be fixed in this session, explicitly state WHY (e.g. "this requires
   user credentials we don't have access to") and create a tracked follow-up via mcp__ccd_session__spawn_task
   or a memory file — not a vague "we'll get to it later".

Then re-send the response without the forbidden phrases.
EOF

exit 2
