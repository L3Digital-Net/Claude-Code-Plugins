# Drift Finding Template

Canonical format for findings emitted by the `up-docs-audit-drift` sub-agent. Emitted in **two forms**: a machine-readable JSON block (so the orchestrator can re-feed findings into propagators as a new session-change summary) and a human-readable markdown table (so the user can read the combined report).

## JSON Form (canonical artifact)

```json
{
  "findings": [
    {
      "id": 1,
      "layer": "wiki",
      "page": "<page title or file path>",
      "page_id": "<Outline/Notion page ID, or null for repo>",
      "stale_line": "<exact text as it currently appears>",
      "should_say": "<what it should be, based on live state or session summary>",
      "confidence": "low | medium | high | unverifiable",
      "destructive_fix": false,
      "evidence": "<command or reference that produced ground truth — NEVER fabricate>"
    }
  ],
  "escalation": {
    "triggered": false,
    "reasons": []
  },
  "stats": {
    "total_findings": 0,
    "by_layer": {"repo": 0, "wiki": 0, "notion": 0},
    "high_confidence": 0,
    "unverifiable": 0,
    "destructive_fixes_required": 0
  }
}
```

## Field Rules

| Field | Rule |
|-------|------|
| `id` | Sequential from 1. Stable across JSON + markdown so a user can cross-reference. |
| `layer` | Exactly one of: `"repo"`, `"wiki"`, `"notion"`. |
| `page` | Human-readable page title (Outline, Notion) or file path (repo). |
| `page_id` | Machine ID for wiki/Notion; `null` for repo. Used by downstream propagators to target the right page. |
| `stale_line` | Exact text currently in the doc. Do not paraphrase. This is what a propagator will match against. |
| `should_say` | What the line should be. If unknown (low confidence), copy `stale_line` and note in `evidence`. |
| `confidence` | `"high"` = verified against live state; `"medium"` = verified against another doc or the session summary; `"low"` = unverified but smells wrong; `"unverifiable"` = verification command was attempted and failed (use when you would otherwise have been tempted to fabricate). |
| `destructive_fix` | `true` if the fix would require page deletion, collection reorg, or anything that can't be cleanly undone. |
| `evidence` | Exact verbatim output of the verification command that produced ground truth — never summarized, never paraphrased, never inferred. If the command failed (non-zero exit, empty output, "No such file" error): set `confidence` to `"unverifiable"` and write `"Command failed: <exact error>"` here. Empty string is allowed only for `"low"` confidence findings where no command was attempted (e.g., host unreachable). **Never fabricate this field** — a finding with invented evidence is worse than no finding. See the agent prompt's `<verification_discipline>` block. |

## Markdown Form (rendered for user)

```markdown
## Drift Audit Findings

**Context:** <1-2 sentences about what was scanned and why>

| # | Layer | Page | Stale Content | Should Say | Confidence |
|---|-------|------|---------------|------------|------------|
| 1 | Wiki | OpenBao — CT 111 | `BAO_ADDR=127.0.0.1:8200` | `BAO_ADDR=100.90.121.89:8200` | high |
| 2 | Notion | Homelab / Backup | Backup uses 127.0.0.1 | Backup uses 100.90.121.89 | medium |
| 3 | Repo | docs/deployed.md | Old `MAXAGE=20` | `MAXAGE=30` | high |

**Totals:** 3 findings | 2 high-confidence | 0 requiring destructive fix
```

Code in `Stale Content` and `Should Say` columns goes in backticks when it's literal configuration or command text.

## Escalation Triggers

Emit the escalation block when any of these hold:

1. `stats.total_findings > 10` — architectural drift suspected; Opus reasoning may help prune false positives.
2. Any affected doc is > 1000 lines — 1M context meaningfully matters.
3. Any finding has `destructive_fix: true`.
4. Cross-layer contradiction detected (wiki says X, Notion says Y, code says Z).

Escalation does not change the findings — it just adds an advisory block to the output recommending the user re-run with Opus or review findings manually before dispatching propagators.

## Escalation Block Form

```markdown
## ⚠ ESCALATION RECOMMENDED

Reasons:
- <trigger 1>
- <trigger 2>

Recommended action: <concrete next step, e.g., "re-run audit with Opus" or "review finding #3 manually">
```
