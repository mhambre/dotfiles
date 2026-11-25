# Security review

Invoke `security-review` with the Skill tool in the current checkout. Use the
command's standard scope and report every substantiated security finding.
The built-in command has no max-findings flag.

Check staged changes, unstaged changes, and relevant untracked source files
for security issues that the built-in branch comparison misses. Use the
optional comment as review guidance. Keep this stage read-only. Explain
which security control is missing or incorrect and how to fix it. Use static
inspection and omit exploit code, payloads, and reproduction steps.

Return each finding with a file and line, severity, evidence, and proposed
fix. If the built-in review fails, report the blocker and label any findings
from your supplementary inspection accordingly. If it succeeds with no
findings, say so.
