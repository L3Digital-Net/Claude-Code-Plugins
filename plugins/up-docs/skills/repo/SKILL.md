---
name: up-repo
description: "Update repository documentation (README.md, docs/, CLAUDE.md) based on session changes by dispatching the up-docs-propagate-repo sub-agent. This skill should be used when the user runs /up-docs:repo."
argument-hint: ""
allowed-tools: Read, Bash, Agent
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

Invoke the sub-agent via the Agent tool with `subagent_type: "up-docs-propagate-repo"`. The prompt has the session-change summary at the stable front, followed by any repo-specific context (CLAUDE.md `## Documentation` section if present).

### 4. Pass the Sub-agent's Output Through

The sub-agent returns a markdown table conforming to `templates/summary-report.md` single-layer "Repo" format. Emit it as the skill's final output. Do not make your own edits — the sub-agent did the work.

If the sub-agent fails entirely (MCP timeout, spawn error), report a single-row table noting the failure with a one-sentence reason.

## Notes

- This skill no longer reads or edits files directly. All file work happens inside the sub-agent's isolated context, which keeps the main session's context window slim.
- Layer boundaries (what belongs in repo docs vs wiki vs Notion) are inlined in the sub-agent's system prompt — not duplicated here.
