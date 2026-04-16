---
name: verify
description: Run verification checks before declaring any task done. Checks imports, stubs, CI status, infrastructure health, and recent execution evidence.
triggers:
  - /verify
  - verify everything
  - run verification
  - check everything works
user_invocable: true
---

# /verify — Pre-Completion Verification Checklist

Run this skill BEFORE declaring any task, fix, or feature done. It checks
whether the work was actually verified, not just coded.

## Instructions

Run every check below in order. Report each as PASS or FAIL with evidence.
Do NOT skip checks. Do NOT report PASS without running the actual command.

### Check 1: Stubs and TODOs

Run:
```bash
grep -rn "# TODO\|# Future:\|# STUB\|raise NotImplementedError\|# FIXME\|# HACK\|# XXX" --include="*.py" . 2>/dev/null | grep -v node_modules | grep -v ".git/" | grep -v __pycache__ | head -20
```

- PASS: zero results, or only pre-existing items unrelated to current work
- FAIL: any stub markers in files you touched this session

### Check 2: Import tests

For every Python file created or modified this session, run:
```bash
python -m py_compile <file>
```

- PASS: all compile cleanly
- FAIL: any syntax or import error

### Check 3: CI workflow status

Run:
```bash
gh run list --limit=5 --json name,conclusion,createdAt 2>/dev/null
```

- PASS: all recent workflows succeeded, or failures are unrelated to current work
- FAIL: any workflow related to current work is failing

### Check 4: Recent execution evidence

Check whether the code you built/changed has actually been EXECUTED (not just
written). Look for:
- A workflow run that used the new code path
- A local test run with real output
- A manual dispatch that completed

Run:
```bash
gh run list --limit=10 --json name,conclusion,createdAt,event 2>/dev/null
```

- PASS: the relevant workflow ran after the latest code change and succeeded
- FAIL: the new code has never been executed in CI or locally

### Check 5: Infrastructure health (mcd-agents specific)

If working in the mcd-agents repo, also check:

```bash
# BigQuery secrets exist
gh secret list 2>/dev/null | grep -i "BQ\|BIGQUERY"

# Check if BigQuery data is actually flowing (not just secrets set)
# This requires running a query — note if you can't verify

# Brain lint CI
gh run list --workflow=brain-lint.yml --limit=1 --json conclusion 2>/dev/null

# Dream cycle
gh run list --workflow=dream-cycle.yml --limit=1 --json conclusion 2>/dev/null

# CPC agent
gh run list --workflow=cpc_agent.yml --limit=1 --json conclusion,createdAt 2>/dev/null
```

- PASS: all infrastructure is confirmed working with real data
- FAIL: any infrastructure claimed as "set up" is not actually functional

### Check 6: Claim verification

Re-read the SESSION_SUMMARY.md or RESUME_HERE.md if they were updated this
session. For every claim made in those files:
- Is it actually true right now?
- Can you verify it with a command?
- Did you verify it, or did you just write it?

### Output format

Report results as:

```
/verify results:
  [PASS] Stubs: no TODO/STUB/Future markers in changed files
  [PASS] Imports: all 5 modified .py files compile clean
  [FAIL] CI: brain-lint.yml failing — 1,356 citation errors
  [FAIL] Execution: cpc_run.py has never run in CI
  [PASS] Infrastructure: Meta API v25 confirmed, Apify token set
  [FAIL] Infrastructure: BigQuery GA4 export link failed (403)

  3 PASS, 3 FAIL — DO NOT claim completion until failures are resolved
```

If ANY check is FAIL, you MUST either fix it or explicitly state why it
cannot be fixed in this session (with a tracked follow-up). You cannot
declare the task done with unresolved FAIL checks.
