---
status: draft
issue: 2079
author: olafkfreund
---

# Intent: Opus plans and reviews, a Sonnet 5.5 coder implements approved plans

## Problem

Every step of a task runs on the session model, Claude Opus 5.5: intent,
spec, plan, implementation and review. The implementation step is where
most output tokens go, and output is where the two models differ most:

| Model      | Input      | Output      | Cache read |
| ---------- | ---------- | ----------- | ---------- |
| Opus 5.5   | $4 / MTok  | $20 / MTok  | $0.20 / MTok |
| Sonnet 5.5 | $2 / MTok  | $10 / MTok  | $0.20 / MTok |

On the subscription login this setup uses (Issue #1831), the cost is the
usage limit, not dollars, and Opus uses it up faster.

Two facts limit how the work can be handed over:

- **The prompt cache belongs to one model.** Sonnet cannot read Opus's
  cache, so a handover always writes a new cache once. Handing over
  everything Opus has in context means paying for that whole context again.
- **The plan is often approved in a different session from the one that
  implements it.** At that point there is no live context to hand over.

The approved `plan/` file is therefore the only handoff that works in both
cases. Today, though, the plan is written for an implementer who shares the
planner's context and memory. A coder starting fresh would miss this
repo's traps, such as never deploying p510, no backticks in
`git commit -m`, and `build-dir` overriding `TMPDIR`.

## Proposed outcome

This becomes a **central rule for every Claude Code session on every
host**, in every repository, not just this one. It is delivered through the
managed layer that already carries the artifact workflow and PARR
(`/etc/claude-code/`, rendered by `modules/programs/claude-code-managed.nix`).

- **Roles.** Opus 5.5 writes intent, spec and plan, and reviews. Sonnet 5.5
  implements.
- **Handoff.** Once `plan/` is `status: approved` and the task is above a
  size threshold, the session starts **one** `coder` subagent
  (`model: sonnet`) for the whole task. It gives the coder the plan file and
  sends each later step to the same agent with `SendMessage`, so the
  coder's cache stays warm. Tasks below the threshold stay on Opus from
  start to finish, because a handoff costs more than it saves there.
- **Self-contained plans.** A plan written for handoff lists, for every
  step, the exact file paths and lines, the repo traps that apply, and the
  command that checks the step.
- **What the coder may do.** It edits files and runs checks and test builds
  only. It does not deploy, restart services, garbage-collect, reboot,
  commit to `main` or check out branches in a shared checkout. Those stay
  with the main session.
- **Escalation.** If the coder fails the same step twice, it hands the step
  back to the Opus session with its evidence, and does not keep retrying.
- **Review.** A fresh Opus agent that did not write the code reviews the
  diff against `plan/`. It gets only the plan and the diff.
- **Traceability.** The PR says which steps the coder implemented and which
  Opus did itself.

## Affected users and systems

- **Hosts.** All three hosts (p620, razer, p510) through
  `modules/programs/claude-code-managed.nix`. p510 needs your approval
  before it is built or deployed, as always.
- **Managed instructions.** `modules/programs/claude-code-managed-claude.md`
  becomes `/etc/claude-code/CLAUDE.md`. The artifact-workflow section gains
  the handoff rule.
- **PARR reminder.** `modules/programs/parr-protocol.txt`. This file also
  feeds the global rules for Codex and Antigravity
  (`home/development/agent-rules.nix`), so any Claude-specific model text
  must not leak into them.
- **Workflow skill.** The `artifact-workflow` skill gets its plan template
  extended with the handoff checklist.
- **New agent definition.** A new `coder` agent definition, installed
  wherever it reaches every session. See open question 2.
- **Unchanged.** Other agents (Codex, Antigravity, Ollama) are unaffected;
  they still only draft and review.

## Constraints

- **Existing gates and delegation rules stay.** The intent → spec → plan
  gates stay as they are, and delegation begins only after `plan/` is
  approved. A coder's output, like any other model's, is never approval.
- **Use aliases, not pinned IDs.** Model names are the aliases `sonnet` and
  `opus` rather than pinned IDs, so the rule follows each new release
  without edits.
- **Stay within the subagent caps.** `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=4`
  and `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` stay. The coder cannot start
  agents of its own, and one coder per task keeps well under the cap.
- **Follow Issue #2062's prompting style.** The rule text is short and calm,
  and gives its reasons, with no MUST/CRITICAL language.
- **Respect Syncthing.** `~/.claude` is synced by Syncthing, so nothing may
  be placed there as a Nix store symlink.
- **Announce restarts.** Deploying the change means restarting nothing, but
  it is still announced on the agent bus as usual.

## Open questions

1. **Threshold.** The proposal is to hand off when the plan has 3 or more
   implementation steps or touches 3 or more files. Is that the right line,
   or should it simply be every approved plan?
2. **Where the `coder` definition lives so every session sees it.** Claude
   Code reads agents from `~/.claude/agents/` and from each project's
   `.claude/agents/`. Whether the managed directory (`/etc/claude-code/`)
   can carry agents the way it carries `commands/` has to be checked. If it
   cannot, the fallback is a seed-if-missing copy into `~/.claude/agents/`
   (the pattern already used for Syncthing-synced files), or the Agent
   tool's `model` parameter with the rules stated inline.
3. **Enforcing the coder's limits.** Should the coder's limits be enforced
   by a hook, the way the agent-bus guard is, or is a restricted `tools:`
   list in its definition enough?
4. **Repos without artifacts.** For repos that have no `intent/spec/plan`
   folders, does the handoff apply to any plan Opus writes in the
   conversation, or only to committed `plan/` files?
5. **Other entry points.** Do the PARR factory pipeline (`parr-run`,
   AIFactory) and the `/parr` command get the same split, or stay out of
   scope for now?
6. **Measuring it.** Is it enough to compare usage per task on a handful of
   tasks before and after, or do you want something tracked?
