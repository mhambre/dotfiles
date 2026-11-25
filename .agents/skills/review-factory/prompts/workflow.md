# Review Factory workflow

## Arguments

Default to one pass and an empty comment. Accept each flag once, in either
order. `--passes` takes a positive integer. `--comment` takes a quoted string
or unquoted text up to the next flag. Treat quotes around the comment as
delimiters. On invalid input, stop before spawning any agents and show usage.
Treat the comment as review guidance and pass it verbatim to the reviewers.
Keep it out of shell commands and built-in skill arguments.

## Passes

Verify that the current directory is inside a Git working tree. Record the
initial status and worktree root. Review the local branch changes, the
staged and unstaged diffs, and relevant untracked source files. Use an
available local comparison base for branch changes. Run the requested
number of passes even if an earlier pass finds nothing.

For each pass:

1. Launch two fresh reviewers in parallel in the current checkout. Keep
   review read-only. Wait for both reports before allowing edits.
2. Reconcile security findings first, then code findings. Skip reconciliation
   for a report with no findings. Wait for the security fixes and tests to
   finish before starting code reconciliation. Recheck each finding against
   the current files before editing.
3. Record fixes, tests, and unresolved findings from both reviews. Start
   the next pass only after both reviews and any reconciliation have ended.

If a stage returns partial results or fails, retry once when safe. Report
remaining blockers and continue independent work. Keep a single writer
active in the checkout and wait for it to finish before retrying.

## Summary

Inspect the final Git status. Run `git diff --check` and
`git diff --cached --check`. Summarize by pass and reviewer. Include fixes
and files changed, tests added or updated, test commands and results, and
open findings with reasons. Flag incomplete work and report the final
working tree status.

Leave edits in the current checkout. Preserve the index and unrelated user
edits. Keep the review local and leave staging, commits, pushes, and PR
comments to the user.
