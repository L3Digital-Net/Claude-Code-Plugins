# UX & Output Templates

All output templates for Design Assistant. Templates are the contract between the plugin logic and the user: consistent formatting across every session.

## Design Principles

- **Lead with findings, not intent.** No preamble before results.
- **Decisions use AskUserQuestion.** All decision points use interactive options. Plain text for progress. These never mix.
- **Show structure at transitions.** Phase headers and synthesis blocks orient the user.

---

## /design-draft Templates

### Template 1 — Entry Point Confirmation

```
✓ ENTRY POINT RESOLVED
──────────────────────────────────────────────────────────────────────
Mode: [File loaded: path/to/file | Inline content received: ~N lines |
       No content — starting blank]
Pre-populated context: [list fields extracted, or "None"]
Proceeding to Phase 0.
──────────────────────────────────────────────────────────────────────
```

### Template 2 — Entry Point Error: File Not Found

```
✗ ENTRY POINT — FILE NOT FOUND
──────────────────────────────────────────────────────────────────────
Could not read: [path as provided]
[Error detail if available]

Options:
  (A) Try a different path — I'll provide it now
  (B) Paste content directly instead
  (C) Start blank — no seed content
──────────────────────────────────────────────────────────────────────
```

### Template 3 — Entry Point Error: Unexpected File Type

```
⚠ ENTRY POINT — UNEXPECTED FILE TYPE
──────────────────────────────────────────────────────────────────────
[filename] appears to be a [type] file, not a design document or notes.

Options:
  (A) Use it anyway — treat its contents as project context
  (B) Provide a different file — I'll give the path
  (C) Paste content directly instead
  (D) Start blank — ignore this file
──────────────────────────────────────────────────────────────────────
```

### Template 4 — Entry Point: Argument Ambiguous

```
❓ ENTRY POINT — ARGUMENT AMBIGUOUS
──────────────────────────────────────────────────────────────────────
"$ARGUMENTS" could be a project name or a file path.

  (A) It's a project name — use it as the project name and start
      Phase 0 with that context pre-loaded
  (B) It's a file path — let me provide the correct path
  (C) Neither — start blank
──────────────────────────────────────────────────────────────────────
```

### Template 5 — Entry Point: Possible Wrong Command

```
⚠ ENTRY POINT — POSSIBLE WRONG COMMAND
──────────────────────────────────────────────────────────────────────
[filename] looks like a completed or near-complete design document
rather than project notes or a brief.

/design-draft is for authoring new documents.
/design-review is for auditing existing ones.

  (A) I want to review and improve this document
      → run /design-review [filename] instead
  (B) I want to draft a new document using this as reference context
      — continue with /design-draft
  (C) This is rough notes that look polished — continue as intended
──────────────────────────────────────────────────────────────────────
```

### Template 6 — Orientation Questions

```
DESIGN DOCUMENT AUTHORING — PHASE 0: ORIENTATION
══════════════════════════════════════════════════════════════════════
Before we write anything, I need to understand what we're designing
and why. I'll ask questions in stages — don't worry about having
perfect answers, rough thinking is fine at this point.
══════════════════════════════════════════════════════════════════════

Q1. What is the name of this project or system?

Q2. In one or two sentences, what problem does it solve — and for whom?
    (Don't describe the solution yet, just the problem and who has it.)
```

### Template 7 — Orientation Summary

```
ORIENTATION SUMMARY
──────────────────────────────────────────────────────────────────────
Project: [name]
Problem: [summary]
Stakeholders affected: [inferred from problem statement]
Document trigger: [trigger]
──────────────────────────────────────────────────────────────────────
Does this capture it? Any corrections before we continue?
  (A) Yes, proceed to Phase 1
  (B) Let me correct something
```

### Template 8 — Context Deep Dive: Round 1

```
PHASE 1: CONTEXT — GOALS & CONSTRAINTS
──────────────────────────────────────────────────────────────────────
Q1. What does success look like in 6 months? In 2 years?

Q2. What are the hard constraints you're working within?

Q3. What has been tried before that didn't work — and why?

Q3b. [Forced tradeoff] Of the goals and constraints: if you had to
     ship half the goals but remove zero constraints, vs. relax one
     hard constraint to hit all goals — which would you choose?
──────────────────────────────────────────────────────────────────────
```

### Template 9 — Tension Detected (Phase 1)

```
⚠ TENSION DETECTED (Phase 1)
──────────────────────────────────────────────────────────────────────
You said "[answer A]" and also "[answer B]". These are in tension.
I'm noting this now — it will surface as a scenario in Phase 2C.
For now, can you tell me which of these is the harder constraint?
──────────────────────────────────────────────────────────────────────
```

### Template 10 — Context Deep Dive: Round 2

```
PHASE 1: CONTEXT — STAKEHOLDERS & PRESSURES
──────────────────────────────────────────────────────────────────────
Q4. Who are the key stakeholders and what do they each want?

Q5. Who will build and operate this system day-to-day?

Q6. What keeps you up at night about this project?

Q6b. [Forced tradeoff] If keeping one stakeholder group fully
     satisfied required disappointing another, which group's needs
     does this system protect first?
──────────────────────────────────────────────────────────────────────
```

### Template 11 — Context Deep Dive: Round 3

```
PHASE 1: CONTEXT — DOMAIN & QUALITY
──────────────────────────────────────────────────────────────────────
Q7. Name your top 3 quality attributes, in priority order:
     1  Correctness        2  Performance        3  Reliability
     4  Security           5  Scalability        6  Maintainability
     7  Simplicity         8  Cost efficiency    9  Developer experience
    10  User experience    (Other: name it)

Q9. Are there any existing standards, patterns, or governance bodies
    this design must pass through?
──────────────────────────────────────────────────────────────────────
```

### Template 12 — Context Synthesis

```
CONTEXT SYNTHESIS
══════════════════════════════════════════════════════════════════════
Project: [name]
Domain: [inferred domain type]
Primary stakeholders: [list with their core interests]
Hard constraints: [list]
Top quality attributes: [ranked list with rationale]
Non-negotiable: [single most important attribute]
Key risks identified: [list]
Prior art / lessons learned: [summary]
Governance / standards requirements: [list or None]
══════════════════════════════════════════════════════════════════════
Does this synthesis accurately reflect the context?
  (A) Yes — proceed to Phase 2: Principles Discovery
  (B) I need to correct or add something
```

### Template 13 — Candidate Principles (compact)

```
PHASE 2A: CANDIDATE PRINCIPLES ([N] candidates)
══════════════════════════════════════════════════════════════════════
Here are the design principles I believe this project operates by.
These are inferences from what you told me — not best practices.
We'll stress-test and lock each one in Phase 2B.
══════════════════════════════════════════════════════════════════════

[PC1] [Principle Name]
  "[One-sentence declarative statement]"
  Inferred from: "[brief quote or paraphrase — 10 words max]"
  Tension: [None | ⚠ conflicts with PC[N]]

[... one block per candidate ...]
══════════════════════════════════════════════════════════════════════
```

### Template 14 — Candidate Principles (full details)

```
──────────────────────────────────────────────────────────────────────
[PC1]: [Principle Name]
──────────────────────────────────────────────────────────────────────
Inferred from: "[direct quote or paraphrase from the human's answers]"
Statement: [declarative sentence — how the team should make decisions]
In practice this means: [2-3 concrete examples]
Cost of violation: [what goes wrong if this is ignored under pressure]
Tension flag: [None / Conflicts with PC[N] — see Phase 2C]
```

### Template 15 — Stress Test Questions

```
STRESS TEST — [PC N]: [Principle Name]
──────────────────────────────────────────────────────────────────────
Statement: "[principle statement]"

ST1. Can you give me a specific example where following this principle
     would force you to do something uncomfortable or expensive?

ST2. Has your team ever violated this principle? What happened?

ST3. If this principle were engraved above your team's door, what's
     the first decision you'd make differently?

ST4. [If tension flag]: This principle may conflict with [PC N].
     Walk me through a scenario where you'd choose between them.
──────────────────────────────────────────────────────────────────────
```

### Template 16 — Stress Test Verdict

```
STRESS TEST VERDICT — [PC N]
──────────────────────────────────────────────────────────────────────
Verdict: [STRONG / NEEDS REFINEMENT / TOO VAGUE / SPLIT]

Cost of following this principle:
  [One or two sentences — what the team gives up under pressure.]

[If NEEDS REFINEMENT or TOO VAGUE:]
Current statement: "[original]"
Proposed revision: "[tighter, more specific statement]"
Reason: [one sentence — must reference something the human said]

  (A) Accept revision — update candidate
  (B) I prefer a different wording — I'll provide it
  (C) Drop this principle entirely
  (D) Keep as-is — I disagree with the verdict
──────────────────────────────────────────────────────────────────────
```

### Template 17 — Tension Resolution Scenario

```
PHASE 2C: TENSION RESOLUTION
══════════════════════════════════════════════════════════════════════

TENSION [T1]: [PC A] vs [PC B]
──────────────────────────────────────────────────────────────────────
[PC A]: "[statement]"
[PC B]: "[statement]"

SCENARIO: [Concrete, domain-specific scenario where these two
  principles directly conflict.]

Resolution options:
  (A) [PC A] wins — add tiebreaker
  (B) [PC B] wins — add tiebreaker
  (C) Context-dependent — define the rule
  (D) Rewrite one principle to eliminate the tension
  (E) Acceptable tension — acknowledge in both statements
──────────────────────────────────────────────────────────────────────
```

### Template 18 — Tension Resolution Log

```
TENSION RESOLUTION LOG
──────────────────────────────────────────────────────────────────────
T1: [PC A] vs [PC B] → [Resolution type] — [one-line summary]
T2: [PC C] vs [PC D] → [Resolution type] — [one-line summary]
──────────────────────────────────────────────────────────────────────
```

### Template 19 — Registry Lock (compact)

```
PHASE 2D: PRINCIPLES REGISTRY — FINAL CONFIRMATION
══════════════════════════════════════════════════════════════════════
These are the [N] design principles for [project name].
Review and lock to proceed to Phase 3.

[P1] [Principle Name]
     Statement: "[declarative statement]"
     Cost: "[what the team gives up when following this under pressure]"
     [Tiebreaker: "[rule]"  ← omit if None]

[...one compact block per principle...]
══════════════════════════════════════════════════════════════════════

  (A) Lock registry — proceed to Phase 3
  (B) Show full details before deciding
  (C) I want to make changes before locking
  (D) Add one more principle I thought of
```

### Template 20 — Registry Lock (full details)

```
──────────────────────────────────────────────────────────────────────
[P1] [Principle Name]
──────────────────────────────────────────────────────────────────────
Statement: "[clear, declarative sentence]"
Intent: [What problem does this principle prevent?]
Enforcement Heuristic: [What does a violation look like?]
Auto-Fix Heuristic: [What does a compliant resolution look like?]
Cost of Following: [From Phase 2B stress test verdict.]
Tiebreaker: [Resolution rule from Phase 2C, or "None".]
Risk Areas: [Sections most likely to violate this principle.]
[Dissent note, if any]
──────────────────────────────────────────────────────────────────────
```

### Template 21 — Phase 3: Section Structure

```
PHASE 3: SCOPE & STRUCTURE
══════════════════════════════════════════════════════════════════════
  ✓ Required    — must be present
  ~ Recommended — important but could be deferred
  ○ Optional    — domain-specific or situationally valuable

──────────────────────────────────────────────────────────────────────
  ✓  1. Overview & Problem Statement
  ✓  2. Goals & Non-Goals
  ✓  3. Design Principles  [locked in Phase 2]
  ✓  4. [Domain-appropriate core section]
  ✓  5. [Domain-appropriate core section]
  ✓  6. [Domain-appropriate core section]
  ~  7. Security Model
  ~  8. Error Handling & Failure Modes
  ~  9. Observability & Monitoring
  ~  10. Testing Strategy
  ○  11. Migration / Upgrade Path
  ○  12. Deployment & Environment Configuration
  ○  13. Open Questions & Decisions Log
  ○  14. Appendix
══════════════════════════════════════════════════════════════════════
```

### Template 22 — Phase 4: Content Questions

```
PHASE 4: TARGETED CONTENT QUESTIONS
══════════════════════════════════════════════════════════════════════
A few targeted questions before I draft. I'll only ask about sections
where I don't yet have enough to write something useful.
══════════════════════════════════════════════════════════════════════

ROUND [N] — [Section Group Name]
──────────────────────────────────────────────────────────────────────
Q[N]. [Targeted question derived from section requirements]
──────────────────────────────────────────────────────────────────────
```

### Template 23 — Coverage Sweep

```
── COVERAGE SWEEP
──────────────────────────────────────────────────────────────────────
Constraint/Risk/Governance: "[item from answers]"
Proposed: Address in Section [X] / Log as OQ[N]: "[question]"
  (A) Accept proposed assignment
  (B) Assign to a different section — I'll specify
  (C) Log as open question with different framing
  (D) This is already covered — it's implicit in [section]
──────────────────────────────────────────────────────────────────────
```

### Template 24 — Draft Complete

```
══════════════════════════════════════════════════════════════════════
DRAFT COMPLETE
══════════════════════════════════════════════════════════════════════
Document: [title]
Sections generated: [n] ([n] complete, [n] stubbed)
Principles locked: [n]
Open questions logged: [n]
Hard constraints addressed: [n of n]
Risks addressed: [n of n]
Governance requirements addressed: [n of n]

Design principles summary:
  [P1] [name] — [one-line summary]
  ...

Stubs requiring content:
  [section name] — [what's needed]
  ...

Open questions requiring decisions before implementation:
  [OQ1] [question summary]
  ...
══════════════════════════════════════════════════════════════════════

NEXT STEPS
──────────────────────────────────────────────────────────────────────
  (A) Save draft to file
  (B) Begin /design-review immediately on this draft
  (C) Make changes before review
  (D) Export principles registry separately
──────────────────────────────────────────────────────────────────────
```

---

## /design-review Templates

### Template 25 — Section Status Table

```
SECTION STATUS TABLE (Pass N)
──────────────────────────────────────────────────────────────────────
Section  | Status   | Last Changed | P-Flags | G-Flags
──────────────────────────────────────────────────────────────────────
```
Status values: `Clean` | `Flagged` | `Modified` | `Deferred` | `Pending Review`

### Template 26 — Pass Header

```
═══════════════════════════════════════════════════════════════════════
PASS [N] | Change Volume: [Prior] | Auto-Fix Mode: [A/B/C/D]
Sections Full Review: [list]
Sections Consistency Check Only: [list]
Active Violations & Systemic Issues: Principle:[list] Gap:[list] Systemic:[desc]
═══════════════════════════════════════════════════════════════════════
```

### Template 27 — Findings Queue

```
FINDINGS QUEUE — PASS [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  | Type          | Sev  | Scope         | Section  | Auto-Fix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
Auto-Fix column: `✓ Eligible` | `✗ Ineligible` | `MANUAL ONLY` (PRINCIPLE findings) | `✗ Conflict: Pn`

### Template 28 — Finding (Interactive Mode A)

```
──────────────────────────────────────────────────────────────────────
FINDING #[N] of [Total] | Pass [N] | [TYPE] | [Auto-Fix: ✓/✗]
Section: [section] | Severity: [level]
──────────────────────────────────────────────────────────────────────
[Issue description and risk]

PROPOSED RESOLUTION: [specific fix]

  (A) Accept — implement it
  (B) Accept with modifications
  (C) Propose alternative
  (D) Defer
  (E) Reject
  (F) Escalate — deeper design problem
  (G) Acknowledge gap — address externally [GAP only]
  (H) Switch to auto-fix for remaining eligible findings this pass
──────────────────────────────────────────────────────────────────────
```

### Template 29 — Auto-Fix Summary (Mode B)

```
AUTO-FIX SUMMARY — PASS [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AUTO-FIX ELIGIBLE:
  #[N] | [TYPE] | [Sev] | [Section]
       Violation: [description]
       Auto-fix: [what will be changed]
       Conflict Screening: Passed
       Confidence: HIGH

REQUIRES YOUR REVIEW:
  #[N] | [TYPE] | [Sev] | [Section] | Reason: [why review required]

  (A) Approve auto-fixes — implement all, then surface review findings
  (B) Approve with exclusions — exclude #[list]
  (C) Review all individually
  (D) Reject all auto-fixes
  (E) Show full diff preview before deciding
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Template 30 — Principle Conflict Warning

```
⚠ PROPOSED FIX CONFLICTS WITH [Pn]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Finding #[N]: [original finding type and section]
Proposed fix: [what would resolve the finding]
Principle conflict: [Pn] — [how the fix violates this principle]

  (A) Accept the fix — deliberate exception to [Pn]
  (B) Modify the fix to honour [Pn]
  (C) Revise [Pn] — the principle needs updating
  (D) Defer — flag both the finding and this conflict
  (E) Reject the fix — original finding remains open
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Template 31 — Diff Format

```
IMPLEMENTING FINDING #[N]  [AUTO-FIX per Pn / MANUAL]
──────────────────────────────────────────────────────────────────────
Section [X.X] — [Change Description]
  BEFORE: ┌─── [original text] ───┐
  AFTER:  ┌─── [revised text]  ───┐
  Finding #[N] closed ✓
  [Principle Restored: Pn ✓] [Gap Closed: Gn ✓] [Auto-Fixed per Pn ✓]
──────────────────────────────────────────────────────────────────────
```

### Template 32 — End of Pass Summary

```
══════════════════════════════════════════════════════════════════════
PASS [N] COMPLETE
══════════════════════════════════════════════════════════════════════
Findings: [n] total ([s]S [p]P [g]G [sy]Sy [sh]SH)
  Auto-Fixed: [n] | Manually Resolved: [n] | Deferred: [n] | Rejected: [n]
Change Volume: [level]
Principle Compliance: [P1 ✓/⚠] [P2 ✓/⚠] ...
Gap Coverage: [G1 ✓/⚠/✗] [G2 ✓/⚠/✗] ...
Context Health: [GREEN/YELLOW/RED] | Growth: ~[+N] lines | Cumulative: ~[+N]
══════════════════════════════════════════════════════════════════════

  (A) Begin Pass [N+1]
  (B) Focused section review
  (C) Principle sweep [Pn]
  (D) Gap sweep [Gn]
  (E) Review Deferred Log
  (F) Update a design principle
  (G) Change auto-fix mode
```

### Template 33 — Systemic Issue

```
🔁 SYSTEMIC ISSUE — Finding #[N] | SYSTEMIC
  (A) Address root cause via targeted design change
  (B) Reframe as deliberate tradeoff — update principle/gap definition
  (C) Escalate — focused design discussion
  (D) Override — accept as systemic risk (re-flags at 5+ passes)
```

### Template 34 — Escalation

```
⚡ ESCALATION — Finding #[N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Deeper design problem description]

  (A) Adopt [design direction A]
  (B) Adopt [design direction B]
  (C) I have a different direction
  (D) Defer deeper issue; apply minimal surface fix
  (E) Update a design principle
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Template 35 — Deferred Log

```
DEFERRED FINDINGS LOG
──────────────────────────────────────────────────────────────────────────────
#  | Type     | Section | Sev  | Description              | Pass | Status
──────────────────────────────────────────────────────────────────────────────
                                          Status: Active | RETIRED (→ see #N)
⚠ High-severity deferred items: [n] — resolve before implementation
```

### Template 36 — Completion Declaration

```
╔════════════════════════════════════════════════════════════════╗
║                   DESIGN REVIEW COMPLETE                       ║
╚════════════════════════════════════════════════════════════════╝
Passes: [N] | Findings: [X] | Auto-Fixed: [n] | Manual: [n]
Deferred: [n] | Rejected: [n]
Final Principles: [P1 ✓] [P2 ✓] ...
Final Gap Coverage: [G1 ✓ Adequate] [G2 ✓ Adequate] ...
```

### Template 37 — Auto-Fix Effectiveness Report

```
── AUTO-FIX EFFECTIVENESS REPORT ─────────────────────────────────
Total eligible: [n] | Auto-fixed: [n] | Escalated to manual: [n]
Confidence: HIGH [n] / MEDIUM [n] / LOW [n]
Per-principle: [Pn] [n] eligible, [n] auto-fixed, [n] escalated
```

---

## Template Usage

References should point to this file for output formatting rather than defining templates inline. Use:

> Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template N (Template Name).
