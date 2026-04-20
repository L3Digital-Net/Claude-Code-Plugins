---
name: up-repo
description: "Update repository documentation (README.md, docs/, CLAUDE.md) based on session changes by dispatching the up-docs-propagate-repo sub-agent. This skill should be used when the user runs /up-docs:repo."
argument-hint: ""
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# /up-docs:repo

Update the active repo's docs via the `up-docs-propagate-repo` sub-agent (Haiku).

## Workflow

### 1. Gather Session Context

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history.

### 2. Build the Session-Change Summary

Read `${CLAUDE_PLUGIN_ROOT}/templates/session-change-summary.md` for the canonical format. Produce a concrete summary following that template — name exact keys/values/paths, not vague "updated config" language.

### 3. Dispatch `up-docs-propagate-repo`

Invoke the sub-agent via the Agent tool with `subagent_type: "up-docs:up-docs-propagate-repo"` (the `up-docs:` prefix is required — plugin-defined agents are only addressable through their plugin namespace). The prompt has the session-change summary at the stable front, followed by any repo-specific context (CLAUDE.md `## Documentation` section if present).

### 4. Pass the Sub-agent's Output Through

The sub-agent returns a markdown table conforming to `templates/summary-report.md` single-layer "Repo" format. Emit it as the skill's final output. Do not make your own edits — the sub-agent did the work.

If the sub-agent fails entirely (MCP timeout, spawn error), report a single-row table noting the failure with a one-sentence reason.

### 5. Review Stale File Candidates (conditional)

If the sub-agent's output includes a `## Stale File Candidates` section, present the listed paths to the user via `AskUserQuestion` and execute deletions only on explicit approval:

1. Parse the candidate rows from the sub-agent's markdown table. Each row has a path, reason, and confidence.
2. Build an `AskUserQuestion` with `multiSelect: true`, one option per candidate (up to 4 — if more candidates than 4, batch in subsequent questions or use the first 4 with a "Delete 4; rerun to review remaining" label on the 4th option).
3. Each option label is the filename (basename, not full path, for readability); description carries the reason + confidence verbatim from the agent.
4. For every path the user selects, run `git rm <path>` (do NOT use plain `rm` — staying inside git keeps history recoverable). Report what was deleted.
5. For paths the user does NOT select, leave them alone — no follow-up, no retry.
6. If the user cancels the question entirely, skip deletions and continue to Step 6.

If the sub-agent emitted zero stale candidates (or omitted the section entirely), skip Step 5 silently.

### 6. Confirm Updates + Emit Handoff Brief

After the sub-agent's table is displayed (and after any Step 5 deletions), emit both of these in the skill's final output:

**(a) Explicit update confirmation.** One or two lines summarizing the table: files changed vs. files audited-but-unchanged vs. files deleted (if any). Example: `"Updated: docs/handoff.md, docs/conventions.md. Deleted: 2 stale plans (user-approved). Audited no-change: README.md, CLAUDE.md."`

**(b) Handoff for Next Session brief.** Read `docs/handoff.md` (if present) and emit a compact next-session brief using this structure:

```markdown
## 📋 Handoff for Next Session

**Last work:** <top Last Updated line, verbatim or condensed to one sentence>

**Currently deployed:**
- <What Is Deployed bullets — one per row, name + version + state>

**Open items — what remains:**
- <What Remains bullets — unchanged>

**Open bugs:** <"None" if Bugs Found And Fixed log has no unresolved items, otherwise list them>

**Gotchas worth carrying forward:** <one sentence pulling the top 2–3 Gotchas>
```

Keep it scannable — no narrative prose, no full-file dump. If `docs/handoff.md` does not exist, skip this subsection silently (the repo has not adopted the handoff pattern yet).

## Notes

- This skill no longer reads or edits files directly. All file work happens inside the sub-agent's isolated context, which keeps the main session's context window slim.
- Layer boundaries (what belongs in repo docs vs wiki vs Notion) are inlined in the sub-agent's system prompt — not duplicated here.
- The handoff brief in Step 6 is a READ-only excerpt of the updated `docs/handoff.md`; the skill does not edit the file at this stage.
- Step 5 stale-file deletion uses `git rm` (not plain `rm`) so deletions stay in git history and can be reverted. The skill never deletes without explicit `AskUserQuestion` consent, even for candidates the agent marked `high` confidence.
