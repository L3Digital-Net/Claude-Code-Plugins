# Conventions

Short, scannable pattern library for future LLM sessions. Check this file before introducing a new persistent repo pattern. Add new conventions in the same schema below.

## Quick Reference

| ID | Title | Applies when |
| --- | --- | --- |
| DOC-001 | Doc audience split | editing any repo doc — determines prose style vs LLM-first style |
| DOC-002 | Session start | starting work in this repo |
| DOC-003 | Convention changes | adding or revising a repo convention |
| PLUGIN-001 | Plugin-namespaced `subagent_type` | a plugin skill dispatches a plugin-defined agent via the Agent tool |

## DOC-001. Doc audience split

**Applies when:** editing any markdown documentation in this repo.
**Rule:** Write for the file's audience — `README.md` files are human-facing prose; everything else is LLM-facing and must be terse, scannable, and optimized for future Claude Code sessions.

```md
Human-facing (prose OK):
- README.md (root + per-plugin)

LLM-facing (terse, scannable, tables > prose, no narrative framing):
- CLAUDE.md, AGENTS.md
- docs/handoff.md, docs/conventions.md
- docs/specs/*.md, docs/plans/*.md
- any other file under docs/
```

**Why:** All non-README documentation in this repo exists to give future Claude Code sessions reference and instruction, not to be read linearly by a human. LLM-facing prose wastes tokens and hides structure. README.md is the one file that may end up on a human's screen (GitHub page, plugin listing), so it gets conventional English prose. Mixing the two styles degrades both audiences.

**Sources:**
- `CLAUDE.md` (Repo Documentation Standard section)
- `plugins/up-docs/agents/up-docs-propagate-repo.md` `<writing_style>` block

**Related:** DOC-002, DOC-003

## DOC-002. Session start

**Applies when:** starting any session in this repo.
**Rule:** Read `docs/handoff.md` before making changes.

```md
Open `docs/handoff.md`, confirm current state, then proceed.
```

**Why:** The handoff doc is the continuity layer between sessions.

**Sources:**
- `AGENTS.md`

**Related:** DOC-001

## DOC-003. Convention changes

**Applies when:** adding or revising a persistent repo convention.
**Rule:** Record the convention here using the same six-field schema and add it to the quick-reference table.

```md
Update the Quick Reference table and add a new numbered convention section below it.
```

**Why:** A stable schema makes convention lookup deterministic for future sessions.

**Sources:**
- `AGENTS.md`

**Related:** DOC-001, DOC-002

## PLUGIN-001. Plugin-namespaced `subagent_type`

**Applies when:** a plugin skill dispatches a plugin-defined agent via the Agent tool.
**Rule:** Pass the fully-qualified `<plugin-name>:<agent-name>` as `subagent_type` — the bare agent filename is not resolvable from outside the plugin's namespace.

```md
Invoke via the Agent tool with `subagent_type: "up-docs:up-docs-propagate-repo"`.
NOT `subagent_type: "up-docs-propagate-repo"` — returns "Agent type not found".
```

**Why:** Claude Code resolves plugin-defined agents only through their plugin namespace. Bare-name dispatches compile but fail at runtime with "Agent type not found", and the failure does not block the skill from continuing — broken plugin flows silently no-op. Every plugin skill that dispatches an agent is affected.

**Sources:**
- `plugins/up-docs/CHANGELOG.md` (0.4.1 Fixed entry)
- Agent not-found error output lists available agents in the namespaced form.

**Related:** DOC-003
