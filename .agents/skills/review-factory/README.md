# Review Factory

## Install

Get a copy of this dotfiles repository and run the commands for your tool
from the root folder. The commands below work on macOS and Linux.

### Codex and Copilot CLI

Both tools read skills from `~/.agents/skills/`. If your dotfiles already
link `~/.agents` to this repository's `.agents` folder, skip the copy.
Otherwise, run:

```sh
mkdir -p "$HOME/.agents/skills"
cp -R .agents/skills/review-factory "$HOME/.agents/skills/"
```

If you received the files separately, copy the entire `review-factory`
folder into `~/.agents/skills/`.

### Claude Code

Use Claude Code 2.1.319 or later.

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

Start a new session in the repository you want to review.

| Tool | Prompt |
| --- | --- |
| Codex | `$review-factory:review-factory --passes 2 --comment "Focus on token expiry"` |
| Copilot CLI | `Use the /review-factory skill with --passes 2 --comment "Focus on token expiry"` |
| Claude Code | `/review-factory --passes 2 --comment "Focus on token expiry"` |

Codex adds the bundle name as a prefix. Select `review-factory:review-factory`
from the skill picker.

Both flags are optional. The default is one pass. Each pass starts fresh
security and code reviewers in parallel. Fixes and tests run one at a time
in your checkout. The next pass reviews the updated tree. The final report
lists changes, test results, and open findings. Edits stay in the working tree.

Copilot CLI uses separate agents for fixes because its built-in reviewers
are read-only. When a built-in reviewer is unavailable, a general-purpose
subagent uses the same review prompt.

## Edit the prompts

Edit the review prompts in `prompts/security-review.md` and
`prompts/code-review.md`. Edit `prompts/reconcile.md` for fixes and tests,
and `prompts/workflow.md` for arguments, pass order, and reporting.
