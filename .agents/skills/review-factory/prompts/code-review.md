# Code review

Invoke `code-review` with the Skill tool and the exact arguments
`max --max-findings all`. Use the default local diff target. Keep this stage
read-only. Wait for the review's completed report if the skill starts a
child agent.

Use the optional comment as review guidance. Check relevant untracked
source files if the built-in review misses them. Verify findings against the
current code and report every substantiated finding with a file and line,
impact, evidence, and proposed fix. If the built-in review fails, report the
blocker and label any findings from your supplementary inspection accordingly.
If it succeeds with no findings, say so.
