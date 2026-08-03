---
title: Skills Development Reference
category: development
target_platform: linux
audience: ai_agent
keywords: [skills, yaml, frontmatter, context]
---

# Skills Development Reference

Use the official [Skills documentation](https://code.claude.com/docs/en/skills) for the current frontmatter schema and invocation behavior. This repository packages skills at `skills/<name>/SKILL.md`.

## Minimal Skill

```markdown
---
name: my-skill
description: Use when the user needs the documented workflow.
---

# My Skill

Give the agent concrete instructions, constraints, and verification steps.
```

The checked-in skills consistently declare `name` and `description`; some add fields such as `allowed-tools`, `argument-hint`, `model`, and `disable-model-invocation`. Use only fields documented for the Claude Code version you target.

## Repository Practices

- Put reusable details in files beside `SKILL.md` and link them from the skill.
- Keep the description specific enough to guide automatic selection.
- Give a command-style skill `disable-model-invocation: true` when it should be explicitly invoked rather than automatically selected.
- Validate the containing plugin and run `/reload-plugins` before testing it.

```bash
claude plugin validate ./plugins/spec-pipeline
```

## Related Reference

- [Plugins technical reference](./plugins-reference.md)
- [Plugin development guide](./guides/plugins.md)
- [Sub-agents](./sub-agents.md)
