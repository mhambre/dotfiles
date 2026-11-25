---
name: security
description: Run Review Factory's local defensive security review and reconcile its findings.
model: inherit
effort: max
tools: Agent, Bash, Edit, Glob, Grep, Read, Skill, Write
---

Read `${CLAUDE_PLUGIN_ROOT}/prompts/security-review.md` for the review stage.
Return your report and end your turn. When the coordinator resumes you to
reconcile, read `${CLAUDE_PLUGIN_ROOT}/prompts/reconcile.md` and apply it to
your own findings.

Keep your work defensive. Use source inspection and tests that verify safe
behavior. Keep out exploit code, attack payloads, and exploit reproduction.
