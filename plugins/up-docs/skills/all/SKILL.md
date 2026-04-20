---
name: up-all
description: "Update all three documentation layers (repo, wiki, Notion) via parallel sub-agent propagation, then run drift audit. This skill should be used when the user runs /up-docs:all."
argument-hint: ""
allowed-tools: Read, Bash, Agent
---

# /up-docs:all

Orchestrates up-docs: gather session context, build a canonical session-change summary, dispatch three propagator sub-agents in parallel (Haiku), then run the drift auditor (Sonnet), and collate all output into a single combined report.

## Architecture

```
This skill (orchestrator, inherits caller model)
  │
  ├─ run context-gather.sh once
  ├─ assemble canonical session-change summary
  │
  ├─▶ up-docs-propagate-repo     (Haiku, parallel)
  ├─▶ up-docs-propagate-wiki     (Haiku, parallel)
  ├─▶ up-docs-propagate-notion   (Haiku, parallel)
  │
  ├─▶ up-docs-audit-drift        (Sonnet, after propagators complete)
  │
  └─ collate reports → emit combined summary
```

## Workflow

### 1. Gather Session Context (once)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history.

### 2. Build the Canonical Session-Change Summary

Read the template at `${CLAUDE_PLUGIN_ROOT}/templates/session-change-summary.md` and produce a concrete summary following that format. This artifact is the **single critical input** to every sub-agent — garbage in, garbage out. Spend main-agent tokens to produce it well.

Field rules (from the template):
- One numbered item per semantically independent change.
- Name exact keys/values/paths — not "updated config" but "`BAO_ADDR=127.0.0.1` → `100.90.121.89` in `/usr/local/bin/backup-dumps.sh`".
- Every item includes {Change, Reason, Affected area, Files touched, Verifiable against}.

### 3. Dispatch Propagators in Parallel

Invoke the three propagator sub-agents **in a single message with three Agent tool calls** so they run concurrently (the tool was called `Task` before Claude Code v2.1.63 and still accepts that name as an alias). Each receives the session-change summary as the stable front of its prompt; layer-specific detail goes at the end (cache-friendly structure).

| Sub-agent — pass as `subagent_type` | Purpose |
|-------------------------------------|---------|
| `up-docs:up-docs-propagate-repo` | Updates README.md, docs/, CLAUDE.md |
| `up-docs:up-docs-propagate-wiki` | Updates Outline pages at implementation-reference level |
| `up-docs:up-docs-propagate-notion` | Updates Notion at strategic/organizational level |

The `up-docs:` prefix is mandatory — plugin-defined agents are only addressable through their plugin namespace. Calling `Agent` with the bare name (e.g. `"up-docs-propagate-repo"`) returns "Agent type not found".

Each sub-agent returns a single-layer markdown table per `templates/summary-report.md`.

#### Failure handling

If a propagator returns a FAILED row or errors out entirely, record the failure in the combined report as a clear "layer not updated due to <reason>" row for that layer. Do not retry across sub-agents and do not abort the other layers — propagation is independent by design.

### 4. Dispatch Drift Auditor (sequentially, after propagators)

Once all three propagators return, invoke the auditor via the Agent tool with `subagent_type: "up-docs:up-docs-audit-drift"`. Pass it the same session-change summary plus the three propagator reports (so the auditor knows what was already fixed and does not re-report those items).

The auditor returns **both** a JSON findings block and a markdown findings table. It is read-only: it does not fix.

If the auditor emits an `⚠ ESCALATION RECOMMENDED` block, include it in the combined report verbatim.

### 5. Collate and Emit Combined Report

Read `${CLAUDE_PLUGIN_ROOT}/templates/summary-report.md` for the `/up-docs:all` format.

Produce one combined report: a heading per layer, each with its own table and totals line, followed by the drift findings table and (if present) the escalation block.

Do not re-fetch pages or files. Do not make your own edits. Your job after dispatching is pure collation.

## Layer Boundaries (reference)

| Layer | Content Level | Example |
|-------|--------------|---------|
| Repo | Project-specific | "Added `--verbose` flag to the CLI" |
| Wiki | Implementation reference | "Authentik OIDC client config for the new service" |
| Notion | Strategic/organizational | "New monitoring service added to the homelab stack" |

Each sub-agent enforces its own layer boundary via the guidelines inlined in its system prompt. You don't need to re-enforce here — just trust the sub-agent reports and collate.

## When to Offer Opus Escalation

The drift auditor will flag escalation when any of these hold:
- Findings count > 10
- Any affected doc is > 1000 lines
- Cross-layer contradictions detected
- A fix would require destructive action

When an escalation block appears in the auditor output, include it in the combined report **but do not auto-invoke anything**. The user decides whether to re-run with Opus.
