---
bug_id: 4
date: 2026-04-20
title: "`up-docs-audit-drift` agent fabricated verification evidence (reported Hermes v0"
services: [claude-code-plugins]
tags: []
status: fixed
supersedes: null
superseded_by: null
---
# Bug 4: `up-docs-audit-drift` agent fabricated verification evidence (reported Hermes v0

## Summary

`up-docs-audit-drift` agent fabricated verification evidence (reported Hermes v0.8.0 → v1.0.0 drift with invented `version.txt` file output). Root cause: prompt required `evidence` field on every finding without sanctioned escape for command failure, creating completeness pressure that won over accuracy. Fixed by adding `<verification_discipline>` block with omit/unverifiable escape paths, a worked example for the failure case, and a tightened evidence-field rule in the template. Released in 0.5.1.
