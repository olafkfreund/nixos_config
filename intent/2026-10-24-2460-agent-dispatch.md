---
status: approved
issue: 2460
author: olafkfreund
---

# Intent: let Claude dispatch Codex and agy per plan, without being asked each time

Split out of #2453. It builds on the hardened agy guard (#2453) and the
automatic probe (#2463).

## Problem

Claude can already hand a plan step to agy (`agy-implement`) or Codex
(`codex-implement`) to implement, and ask both for a read-only review
(`second-opinion`). Every one of those paths is gated on the user asking at
that moment. The rule appears in four places:

- `AGENTS.md` "Delegating to other models" (lines 47–70): "that the user
  starts, or that Claude starts at the user's request"
- `AGENTS.md` "Claude Code" (line 241): consult other models "only when the
  user asks … Never on your own initiative"
- the `handoff` skill ("Only when the user asks") and the `second-opinion`
  skill ("Never use it on your own initiative")
- the managed CLAUDE.md model split
  (`modules/programs/claude-code-managed-claude.md:32`), which names only the
  Sonnet `coder` agent as an implementer and a fresh Opus agent as reviewer

So a plan the user has approved can't say "agy does step 3, Codex reviews",
and have that happen. The user has to repeat it in chat at each step. The
`team` command (`home/development/claude-code-commands/default.nix`, the
`teamCommand` text) also accepts only Claude workers.

## Proposed outcome

- **A plan names its implementers and reviewers.** An approved `plan/` can
  record, in its frontmatter, who implements each step (`coder`, `agy` or
  `codex`) and who reviews (`opus`, `codex`, `agy`). Approving the plan
  approves that dispatch.
- **Claude follows it without asking again.** It runs `agy-implement` or
  `codex-implement` for the named steps and `second-opinion`-style reviews
  for the named reviewers, as it runs the `coder` agent today.
- **No field means today's behaviour.** A plan without these fields
  dispatches exactly as now: the Sonnet `coder` agent and a fresh Opus
  reviewer. Nothing changes for existing plans.
- **`team` can use them too.** It accepts `codex` and `agy` workers, each in
  its own worktree.
- **The four policy texts say the same thing:** "when the user asks, or when
  an approved `plan/` names it".

## Affected users and systems

- `AGENTS.md`, read by every agent on every host
- `modules/programs/claude-code-managed-claude.md`, the managed CLAUDE.md
  policy deployed to `/etc/claude-code/CLAUDE.md`
- the `handoff` and `second-opinion` skills (`home/development/claude-code-skills/`)
- the `team` command, and the `artifact-workflow` skill's plan template, if
  the new frontmatter fields are documented there
- p620 and razer, which run agy and Codex. p510 runs Claude Code but no agy.

## Constraints

- **Approval stays human and explicit.** Dispatch is allowed only by an
  approved `plan/`, never by Claude deciding mid-task. Output from agy or
  Codex is still untrusted advice, and is never an approval of an intent,
  spec or plan.
- **The guards don't change.**
  - The coder guards stay in force: no commit, deploy, restart, GC or
    reboot for either tool.
  - `agy-implement` keeps its probe gate.
  - Review modes stay read-only.
- Claude still commits, runs each step's check, and reviews against
  `plan/`. The PR still says which steps which tool did.
- Subscription login only (#1831). No sandbox bypass flags beyond what
  `agy-implement` already adds (#2296).
- This is policy text plus skill text. Nothing is deployed beyond the
  rebuilt Home Manager files and `/etc/claude-code/CLAUDE.md`.

## Decisions (approved 2026-10-24)

1. **Per-plan dispatch only** (`coders:` per step and `reviewers:`). Letting
   `team` run Codex and agy workers is out of scope.
2. **Claude may propose the fields in a draft plan.** The user's plan
   approval is the consent.
3. **With no `reviewers:` field, the review stays a fresh Opus agent.**
