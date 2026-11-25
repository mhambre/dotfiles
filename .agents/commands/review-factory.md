---
description: Run the local Review Factory plugin
argument-hint: "[--passes <n>] [--comment <additional comments>]"
disable-model-invocation: true
allowed-tools: Skill(review-factory:run *)
---

Invoke the Skill tool with `skill: review-factory:run` and pass the exact text
below as its `args` value. Use an empty string when there are no arguments.
If the skill is unavailable, report that the Review Factory plugin did not load.

<review-factory-arguments>
$ARGUMENTS
</review-factory-arguments>
