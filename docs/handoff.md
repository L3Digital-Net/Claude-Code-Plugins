# Handoff

> **Status: MIGRATING — do not edit.** Bug table will move to `docs/bugs/` in Phase 2.
> Live state is now in `docs/state.md`.

## Bugs Found And Fixed

1. 2026-04-20 — home-assistant-dev DESIGN_DOCUMENT.md had stale version refs (2.2.2 vs 2.2.6). Fixed and released in 2.2.6.
2. 2026-04-20 — plugin-test-harness TypeScript config missing @types/jest in tsconfig types array; jest transform pointed at wrong config. Fixed and released in 0.7.4 (50 tests now pass, was 0).
3. 2026-04-20 — up-docs orchestrator and five wrapper skills dispatched sub-agents with bare names (e.g. "up-docs-propagate-repo") instead of plugin-namespaced form (e.g. "up-docs:up-docs-propagate-repo"), causing "Agent type not found" errors. Fixed all five skills and released in 0.4.1.
4. 2026-04-20 — `up-docs-audit-drift` agent fabricated verification evidence (reported Hermes v0.8.0 → v1.0.0 drift with invented `version.txt` file output). Root cause: prompt required `evidence` field on every finding without sanctioned escape for command failure, creating completeness pressure that won over accuracy. Fixed by adding `<verification_discipline>` block with omit/unverifiable escape paths, a worked example for the failure case, and a tightened evidence-field rule in the template. Released in 0.5.1.
