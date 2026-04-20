# Conventions

Short, scannable pattern library for future LLM sessions. Check this file before introducing a new persistent repo pattern. Add new conventions in the same schema below.

## Quick Reference

| ID | Title | Applies when |
| --- | --- | --- |
| DOC-001 | LLM-first docs | editing files under `docs/` |
| DOC-002 | Session start | starting work in this repo |
| DOC-003 | Convention changes | adding or revising a repo convention |

## DOC-001. LLM-first docs

**Applies when:** editing files under `docs/`.
**Rule:** Keep `docs/` concise, scannable, and optimized for LLM retrieval.

```md
Use short sections, flat bullets, and tables instead of narrative prose.
```

**Why:** Repo docs are for session continuity and quick lookup, not human-oriented long-form reading.

**Sources:**
- `AGENTS.md`

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
