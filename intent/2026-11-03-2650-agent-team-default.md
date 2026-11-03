---
status: draft
issue: 2650
author: olafkfreund
---

# Intent: Codex and agy as permanent team members, with Claude as manager

## Problem

Codex and agy can already implement plan steps under a guard
(`codex-implement`, `agy-implement`) and review read-only (`second-opinion`),
but they almost never take part:

- Policy makes them opt-in. `AGENTS.md`, the `handoff` and `second-opinion`
  skill descriptions all say "only when the user asks or an approved `plan/`
  names them … never otherwise".
- The opt-in fields stay empty. Since #2460, 0 of 21 plans gave a step to agy
  or Codex; 3 used `reviewers:`.
- They are absent from planning. `reviewers:` acts only on the plan and the
  diff; intent and spec drafts reach the user without another model's critique.
- `/team` spawns Opus teammates, ignores the approved-plan gate and knows
  nothing of agy or Codex, so it works against the model split.
- Every handoff ends in a six-point manual check (exit code, `status`,
  `denied_actions`, empty response, empty diff, moved `HEAD`), which is slow
  and easy to get wrong. The two providers' reviews run one after the other
  for no recorded reason.

## Proposed outcome

- **On by default.** For any task under the artifact workflow, Codex and agy
  critique each intent, spec and plan draft, and the final diff, before
  Claude stops for the user. Their findings are shown with the draft.
- **Claude proposes coders for every plan step** (`coder`, `agy`, `codex`, or
  Claude itself for builds, reviews and deploys), with a one-line reason, and
  manages them: dispatch, check, merge, commit.
- **Opt-out per plan**: the user can drop a reviewer or coder in the plan
  before approving it.
- **A global on/off switch** the user can flip at will, without a rebuild. Off
  restores today's behaviour (opt-in only).
- **Faster loop**: one command runs a handoff and returns a single
  machine-checked verdict; the Codex and agy reviews run in parallel.
- `/team` manages Sonnet `coder`, agy and Codex workers against an approved
  plan instead of spawning Opus teammates.

## Affected users and systems

- The user; Claude Code sessions on p620, razer and p510.
- `AGENTS.md`, `modules/programs/claude-code-managed-claude.md`,
  `modules/programs/claude-code-managed.nix`.
- Skills `handoff`, `second-opinion`, `artifact-workflow`; the `/team`
  command in `home/development/claude-code-commands/default.nix`.
- `codex-implement`, `agy-implement` (`home/development/codex-cli.nix`,
  `home/development/antigravity-config.nix`).
- Subscription quota of ChatGPT (Codex) and Antigravity.

## Constraints

- Codex and agy stay advisory: their output never approves an intent, spec
  or plan, and Claude never self-approves.
- Write access stays exactly as guarded today: only through
  `codex-implement` / `agy-implement`, only for an approved `plan/`, only in a
  task worktree; they never commit, deploy, restart, GC or reboot.
- Subscription login only; no API keys, no sandbox bypass (#1831, #2296).
- Exempt tasks (typos, lock bumps, one-line config) do not trigger reviews.
- A failed or unavailable provider must not block the work: it is reported
  and Claude carries on, as today.
- Parallel coders must not collide on the same files.
- No host deploy needed to flip the switch; p510 is never deployed without
  asking.

## Open questions

- Should the switch be per host, per repo, or per session? (Proposed:
  per user and host, persistent until flipped.)
- When both providers fail or quota runs out, should the switch fall back
  to off automatically or only report? (Proposed: only report.)
