---
name: run
description: Run Review Factory in Claude Code through /review-factory or /review-factory:run.
argument-hint: "[--passes <n>] [--comment <additional comments>]"
---

Run this entry point only in Claude Code and only on explicit user
invocation. In Codex or Copilot CLI, load the Review Factory skill at the
root of this bundle instead. Read
`${CLAUDE_PLUGIN_ROOT}/prompts/workflow.md` for arguments, pass order, and
reporting. Make the agent calls below in the order that prompt specifies.

## Arguments

<review-factory-arguments>
$ARGUMENTS
</review-factory-arguments>

## Claude Code delegation

For each pass:

1. Launch two fresh Agent calls in parallel. Set `subagent_type` explicitly
   to `review-factory:security` and `review-factory:code`. Pass only the
   worktree root, current pass number, review scope, and optional comment.
   Use the current checkout, with no worktree isolation. Keep the parent
   conversation and prior pass reports out of their prompts.
2. Collect both read-only reports and their agent IDs before authorizing
   edits. If agents are running in the background, continue from their
   completion notifications. Track which stage each notification completes.
3. Resume the security agent by ID with SendMessage. If the tool is deferred,
   load it with ToolSearch using `select:SendMessage`. Tell the agent to
   reconcile its own findings in the current checkout. Wait for
   reconciliation to finish before resuming the code agent by ID with the
   same instruction for its findings. Skip reconciliation for a reviewer
   with no findings. The code agent must recheck its findings against the
   security fixes.

If a reviewer cannot be reached, mark its work incomplete. Leave patching
to the assigned agents.
