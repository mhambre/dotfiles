# Review Factory

## Install

Use Claude Code 2.1.319 or later. Get a copy of this dotfiles repository.
From its root folder, run these commands on macOS or Linux:

```sh
mkdir -p "$HOME/.claude/skills" "$HOME/.claude/commands"
cp -R .agents/skills/review-factory "$HOME/.claude/skills/"
cp .agents/commands/review-factory.md "$HOME/.claude/commands/"
```

If you received the plugin files separately, copy the entire
`review-factory` folder into `~/.claude/skills/`. Keep the hidden
`.claude-plugin` folder inside it. Copy `review-factory.md` into
`~/.claude/commands/` to enable the short command. If you only received the
folder, use `/review-factory:run`.

## Run a review

Start a new Claude Code session in the repository you want to review.

```text
/review-factory --passes 2 --comment "Focus on token expiry and error handling"
```

Both flags are optional. With no flags, the plugin runs one pass. Each pass
starts fresh security and code agents in parallel. They apply and test their
fixes one at a time in your checkout, then the next pass reviews the updated
tree. The final report lists changes, tests, and unresolved findings. Edits
stay in the working tree.

## Edit the prompts

Edit the review prompts in `prompts/security-review.md` and
`prompts/code-review.md`, the fix and test prompt in `prompts/reconcile.md`,
and the pass and summary instructions in `skills/run/SKILL.md`.
