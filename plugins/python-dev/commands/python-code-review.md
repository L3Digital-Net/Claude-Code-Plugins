---
allowed-tools: Agent, AskUserQuestion
description: Comprehensive Python code review across 11 quality domains via the python-code-reviewer subagent (Sonnet)
argument-hint: "[path]  (file, directory, or glob — defaults to current directory)"
---

# /python-code-review

Run a comprehensive quality audit across all 11 Python development domains by dispatching the `python-code-reviewer` subagent.

## Why this is a subagent

Running 11 domain passes against every `.py` file in scope is read-heavy, pattern-matching work. The domain rules are documented in the agent prompt; the agent reads the target files, applies all 11 passes, and returns a prioritized findings table. Keeping the raw source content and per-domain reasoning in Sonnet context saves ~20K tokens per review vs. the prior inline implementation.

## How to run it

1. Determine the scope. If `$ARGUMENTS` is provided, use it. Otherwise, default to the current working directory.

2. Dispatch `python-code-reviewer` with the scope.

   Use the `Agent` tool with `subagent_type: python-code-reviewer` and a prompt like:

   > Review the Python code in `<scope>`. Run all 11 domain passes per your task spec and return the prioritized findings report per your output format. Skip domains with no relevant surface.

   Do not read `.py` files or apply domain rules in this session — the agent owns all of that.

## After the agent returns

1. If the agent returns the "no Python files" block, present it verbatim and stop.

2. Otherwise, present the full findings report verbatim to the user. The three-tier summary (🔴 Critical / 🟡 Needs Attention / 🟢 Good) + Top 3 Action Items + Per-Domain Summary is ready to display as-is.

3. If the report shows ≥1 Critical finding, offer follow-up via `AskUserQuestion`:
   - header: `"Next step"`
   - question: `"Critical findings present. How would you like to proceed?"`
   - options:
     1. label: `"Walk fixes one by one"`, description: `"Step through each Critical finding and apply its suggested fix via Edit"`
     2. label: `"Focus area"`, description: `"Pick one domain or file to address first"`
     3. label: `"Just the report"`, description: `"Leave fixes for later"`

   - For `"Walk fixes one by one"`: iterate the Critical rows. For each, use `AskUserQuestion` to Apply / Skip / Modify; apply approved fixes via `Edit` in this session.
   - For `"Focus area"`: ask a follow-up open-ended question for the domain or file, then filter the findings accordingly.
   - For `"Just the report"`: stop.

4. If the report has only 🟡 or 🟢 findings, emit a compact acknowledgement and stop:
   ```
   ✓ No critical issues. N items flagged for future cleanup.
   ```
