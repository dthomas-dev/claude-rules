# Global Rules — Derek Thomas

These rules apply to every Claude Code session, every project, every task.

---

## 🛑 QUADRUPLE CHECK EVERYTHING

This rule applies to EVERYTHING — not just code changes. Every claim,
finding, recommendation, plan, status report, analysis, comparison, and
completion declaration must be verified before presenting it to Derek.

### For code, config, and doc changes

Every change runs through all four layers before being declared done. If
any layer is genuinely impossible for a specific change (e.g., no sandbox
exists for a given API), state so explicitly and get sign-off before
proceeding — do NOT silently skip.

1. **Read existing code first.** No edit to a file without reading it. No
   assumption about how an API behaves without verifying via Context7 or a
   live query. No claim about current state without confirming it from source.
2. **Logic check.** Walk the change through in writing before coding. Why it
   works. Edge cases. Failure modes. What could regress. What assumptions
   it's making.
3. **Functionality test.** Unit-test where possible (synthetic inputs →
   expected outputs). Integration test against real data when unit tests
   cannot cover the surface. A script that ends with `print("SUCCESS")` and
   no assertions is broken by definition.
4. **End-to-end verify.** A real run against real data before declaring done.
   For API mutations: re-query the mutated entity and assert the new state.
   For dashboard changes: load the rendered page and confirm the change is
   visible and functional. Assertions passing alone is not sufficient —
   something has to actually run against the real system.

### For research, findings, and analysis

Before presenting any finding, comparison, status claim, or recommendation:

1. **Verify the source.** Read the actual file, log, or API response. Do not
   state something is true from memory or inference. Re-read it.
2. **Re-verify.** After forming a conclusion, go back to the source and
   confirm the conclusion holds. Check you didn't misread, skip context,
   or conflate two things.
3. **Check the inverse.** Actively look for evidence that contradicts the
   finding. If claiming "X doesn't exist," grep for it. If claiming "X is
   a stub," read the full function.
4. **Confirm completeness.** Before saying "there are N issues," verify
   there aren't N+1. Before saying "these are all the consumers," verify
   no other file references it.

### For plans and proposals

Before proposing any architecture, migration, or integration plan:

1. **Verify every assumption.** Each claim the plan rests on must be
   confirmed by reading the actual code/config/state. "I believe X works
   this way" is not acceptable — read X and confirm.
2. **Verify every interface.** If the plan says "module A will call
   function B," confirm B exists, confirm its signature, confirm it does
   what you think.
3. **Verify existing systems.** Before replacing or merging anything, read
   every line of what exists. Understand what it does, who consumes it,
   and what breaks if it changes.
4. **Verify nothing is missed.** Before proposing, ask: "What existing
   feature, workflow, or integration did I not account for?" Then grep
   and check.

### For completion claims

Before saying anything is "done," "complete," "shipped," or "fixed":

1. **Run it.** Not "it should work" — actually execute it and read the
   output.
2. **Grep for contradictions.** Search for stubs (`# TODO`, `# Future:`,
   `# STUB`, `pass`, `raise NotImplementedError`), wrong imports, dead
   code paths.
3. **Verify the output exists.** If it should produce a file, confirm the
   file exists and contains expected content. If it should trigger a
   workflow, confirm the workflow ran.
4. **Re-verify 24 hours of claims.** Before closing a session, re-check
   every "done" claim made during the session against actual state.

### The bottom line

No shortcut. No "the tests are green so it must work." No "I'm confident
this is right." No "I'll verify after shipping." No "no stubs remain"
without grepping for stubs. No "the new architecture is live" without
confirming it ran. If all four layers are not done for the relevant
category, the work is not done and the claim cannot be made.

---

## 🛑 NO LESSER TOOLS

If the best tool, data source, or API for a job exists, use it — even if
that means a detour to set it up. No proxying, estimating, or working
around when the real thing is available. If it requires infrastructure
that doesn't exist yet, build the infrastructure. Only defer with an
explicit carveout from Derek.

---

## 🛑 NEVER PUNT TO MANUAL

When an automation runs into a missing data source, a failed API call, or
an unverifiable claim — the first instinct must be to SOLVE IT, not to
recommend doing it manually. "Recommend checking manually" / "verify in
the UI" / "do this manually" / "manual intervention required" are not
acceptable first responses.

Walk this fallback ladder before admitting defeat:

1. **Alternate data source** with equivalent info.
2. **Direct API call.** If a helper/SDK fails, try the raw HTTP endpoint.
3. **Archived / prior-run data.** A stale number is better than no number.
4. **Derived signal from existing data.** Infer from what's available.
5. **Spawn a tracked side-task** to fix the broken pull for next time, and
   proceed with what's available now.

Only after ALL FIVE rungs fail do you say the request can't be completed —
and even then, explain WHAT was tried, not just that it didn't work.

---

## 🛑 PROGRAMMATIC FIRST

Never suggest browser automation, manual UI workarounds, or "just open it
in Chrome" shortcuts. Always build proper integrations first — API, MCP,
SDK, service account key. Only mention manual approaches after confirming
no programmatic access exists.

---

## 🛑 ALWAYS VERIFY AFTER MUTATION

Never assume an API call worked just because it returned success/200.
Re-read the state after every mutation to confirm the change stuck.
"Waiting on volume" / "waiting on data" / "needs time to accumulate" /
"give it 24-48h" is not a valid closing state — if the pipeline can't
carry a synthetic test event now, it's broken, not pending.

---

## 🛑 PORTABLE SETUPS

Derek works across multiple computers and multiple Claude Code sessions.
Any credential, token, config, or state created must be reachable from
every machine. Never store source-of-truth state in local-only files.

---

## 🛑 HUMAN IN THE LOOP

Agents propose and draft — Derek approves anything touching money or
customer communications. This is non-negotiable across all projects.

---

## 🛑 FETCH BEFORE EDIT

Always `git pull` before editing any file in a repo. Never assume
local = current.
