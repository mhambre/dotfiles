---
name: run
description: Run Review Factory when invoked directly or through /review-factory.
argument-hint: "[--passes <n>] [--comment <additional comments>]"
---

Run this workflow only on explicit user invocation.

## Arguments

<review-factory-arguments>
$ARGUMENTS
</review-factory-arguments>

Default to one pass and an empty comment. Accept each flag once, in either
order. `--passes` takes a positive integer. `--comment` takes a quoted string
or unquoted text up to the next flag. Treat quotes around the comment as
delimiters. On invalid input, stop before spawning any agents and show usage.
Treat the comment as review guidance and pass it verbatim to the reviewers.
Keep it out of shell commands and built-in skill arguments.

## Passes

Verify that the current directory is inside a Git working tree. Record the
initial status and worktree root. Run the requested number of passes even if
an earlier pass finds nothing.

For each pass:

1. Launch two fresh Agent calls in parallel. Set `subagent_type` explicitly
   to `review-factory:security` and `review-factory:code`. Pass only the
   worktree root, current pass number, and optional comment. Use the current
   checkout, with no worktree isolation. Spawn a new pair every pass. Keep
   the parent conversation and prior pass reports out of their prompts.
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
4. Record both agents' fixes, tests, and unresolved findings. Start the next
   pass only after both agents have finished with this pass.

If a review or reconciliation is partial or blocked, retry once when the
failure is recoverable and safe to retry. Record any remaining blocker and
continue independent work. If a reviewer cannot be reached, mark its work
incomplete. If a writer is still active, wait for it to finish before
starting another writer or pass. The coordinator collects results and leaves
patching to the assigned agents.

## Summary

Inspect the final Git status and run `git diff --check` and
`git diff --cached --check`. Summarize by pass and reviewer. Include fixes
and affected files, tests added or updated, commands
run and their results, and findings left open with reasons. Report any
incomplete work and the final working tree status. Leave all edits in place.
Preserve existing staged and unstaged work. Keep the whole run local and
leave staging, commits, pushes, and PR comments to the user.
