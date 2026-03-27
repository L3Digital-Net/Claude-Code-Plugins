---
name: analyze
description: Force a full gap analysis on the current project. Detects project type, loads stack profile, inventories source and test files, identifies gaps, and optionally enters a convergence loop to fill them.
argument-hint: "[optional: path to scope analysis]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# /test-driver:analyze — Gap Analysis and Test Generation

Run a full test gap analysis on the current project. Optionally enter a convergence loop to generate tests and fill the gaps.

## Step 1: Detect and Load Profile

Read `${CLAUDE_PLUGIN_ROOT}/references/gap-analysis.md` for the full detection methodology.

1. If an argument was provided (e.g., `/test-driver:analyze src/api/`), scope the analysis to that directory.
2. Scan for marker files to detect the project type.
3. Load the matching stack profile from `${CLAUDE_PLUGIN_ROOT}/references/profiles/`.
4. If no profile matches, offer to create one (see gap-analysis reference, "No Profile Match" section).

## Step 2: Read Prior State

Check if `docs/testing/TEST_STATUS.json` exists:
- If present: read it. Note last analysis date, known gaps, current coverage. Read `${CLAUDE_PLUGIN_ROOT}/references/test-status.md` for schema details.
- If missing: this is the first analysis. The file will be created at the end.

## Step 3: Run Gap Analysis

Follow the full gap-analysis methodology (from the gap-analysis reference):

1. Determine applicable test categories from the stack profile
2. Inventory existing tests (Glob for test files, categorize by type)
3. Inventory source files (exclude non-source patterns)
4. Map coverage (structural: which source files have corresponding tests)
5. Identify and prioritize gaps

**opus-context alignment:** Read source files fully (no offset/limit for files under 4000 lines). Read test files in parallel batches.

## Step 4: Present Results and Offer Convergence

If gaps were found, present results using Template 1 (Gap Analysis Report) from `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md`. Follow with the `AskUserQuestion` options defined in that template (fill all, fill specific, record only).

## Step 5: Report

After the convergence loop completes (or if the user chose "Record gaps only"):

1. Update `docs/testing/TEST_STATUS.json` per the test-status reference's update rules.
2. Present a compact summary: gaps found, gaps filled, gaps deferred, coverage status, any source bugs fixed.
