---
name: review-factory
description: Run parallel security and code reviews, apply tested fixes, and repeat for a requested number of passes when the user asks for Review Factory.
---

Run only when the user explicitly requests Review Factory. In Claude Code,
invoke `review-factory:run` with the Skill tool and forward the exact
arguments from the user invocation. If that plugin skill is unavailable,
report that the Claude Code plugin did not load. Use the rest of this file
in Codex and Copilot CLI.

Read [the shared workflow](prompts/workflow.md) for arguments, pass order, and
reporting. Read [security review](prompts/security-review.md),
[code review](prompts/code-review.md), and [reconciliation](prompts/reconcile.md).
Resolve these paths relative to this skill. Include the relevant prompt text
in each delegation so agents can work from the current checkout.

## Codex

Launch two fresh native subagents in parallel each pass, one per review
prompt. Use fresh context (`fork_context: false` if the tool has that
option). Wait for both reports before sending either agent the reconciliation
prompt. Use the existing agent for its own findings if it can receive
follow-up work. If it cannot resume, launch a fresh subagent and pass only
that reviewer's findings and the reconciliation task. Wait for each agent to
finish reconciling before sending the next reconciliation task.

## Copilot CLI

Use the native subagent tool to launch the built-in `security-review` and
`code-review` agents in parallel. If a built-in reviewer is unavailable,
use a fresh `general-purpose` subagent with the corresponding read-only
prompt. Use the shared prompts to scope the reviews and request all
substantiated findings.

The built-in reviewers are read-only. For each report with findings, launch
a fresh `general-purpose` subagent with that report and the reconciliation
prompt. Launch only one reconciliation agent at a time.

## Delegation

Use the guidance for the current host only. Pass the current checkout,
review scope, pass number, relevant stage instructions, and optional
comment. Keep prior conversation and prior pass reports out of new
delegations. If the host cannot launch a fresh native subagent, report
that blocker before making changes.
