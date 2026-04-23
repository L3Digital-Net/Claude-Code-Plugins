---
name: deep-context
description: 1M context window rules. Injected into AI context at every SessionStart. Invoke manually to reload mid-session if the rules drop out of working attention.
---

# 1M Context Rules

1M tokens available. Cost of not reading > cost of reading. These rules override conservative habits optimized for smaller-context models.

## Baseline Rules

1. **Whole-file reads.** Read full files under 4000 lines. For 2000-4000 line files, split into two parallel Read calls.
2. **Direct over delegation.** Glob/Grep to find files, then Read them yourself. Delegate to a subagent only for genuinely broad searches across 10+ unknown files.
3. **Read before edit.** Load target + imports + callers + tests + configs before editing.
4. **No redundant reads.** Trust prior reads. Re-read only after the file was modified.
5. **Parallel reads.** Batch independent Reads into one tool call. Never sequential.

## Deep-Context Planning

Trigger: tasks touching 3+ files, debugging, refactoring, cross-module work, or explicit user request for deep analysis.

1. Scope the file graph via Glob/Grep. No reads yet.
2. Parallel-load in priority: primary targets → direct deps → callers → tests → configs.
3. Execute with full context loaded. No mid-task "let me check" reads.

Announce what you loaded in one sentence.

## Budget

Aggressive in early session; selective once 10-20 files are loaded; deliberate past 30+ files. Never issue a read without a reason.

## Guardrails

Reason for each read. Match scope to task — "fix this one line" doesn't need the module graph. Announce deep loads.
