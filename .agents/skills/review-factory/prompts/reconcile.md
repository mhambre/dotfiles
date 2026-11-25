# Reconcile and test

Recheck each of your findings against the current files before editing.
Account for existing user changes and fixes the other reviewer may have
made. Fix each confirmed issue with a focused change. Record why you skip
any finding, including duplicates, false positives, and blocked fixes.

For every fix, add or update a regression test that exercises the corrected
behavior. Use the project's existing test conventions. For security fixes,
test the defensive control with isolated fixtures and ordinary inputs.
If you cannot add meaningful coverage, leave the finding open and report
the blocker. Run the relevant tests and report their commands and results.
Investigate test failures caused by your changes before returning.

Keep fixes and tests in the current working tree. Preserve unrelated edits
and the existing index. Leave staging, commits, pushes, and PR comments to
the user.

Report the findings you fixed, files changed, tests added or updated, test
results, and any findings still open with reasons.
