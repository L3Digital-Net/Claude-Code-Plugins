---
title: Sub-Agents Reference
category: development
target_platform: linux
audience: ai_agent
keywords: [agents, subagents, tools, permissions, specialization]
---

# Sub-Agents Reference

Use the official [Plugins reference: agents](https://code.claude.com/docs/en/plugins-reference#agents) for the current agent frontmatter and tool-control schema. Plugin agents live in `agents/*.md` at the plugin root.

## Minimal Agent

```markdown
---
name: code-reviewer
description: Review changed code for correctness and missing tests.
model: sonnet
tools: Read, Grep, Glob
---

# Code Reviewer

Inspect the requested files, report findings by severity, and do not modify source unless explicitly authorized.
```

The repository's agents use `name`, `description`, `model`, and `tools`; some also use `color` and MCP tool names. Match the exact tool names exposed by the target Claude Code environment.

## Namespaced Dispatch

When a plugin command or skill dispatches a plugin-defined agent, use the fully-qualified name:

```text
subagent_type: "up-docs:up-docs-propagate-repo"
```

The qdev structure tests enforce this repository convention because bare agent names do not resolve from outside a plugin namespace.

## Develop and Verify

```bash
claude plugin validate ./plugins/up-docs
```

Reload the plugin, then exercise the command or skill that dispatches the agent. Do not assume a direct slash-command invocation unless the target plugin explicitly provides one.

## Related Reference

- [Skills](./skills.md)
- [Plugin development guide](./guides/plugins.md)
- [Plugins technical reference](./plugins-reference.md)
