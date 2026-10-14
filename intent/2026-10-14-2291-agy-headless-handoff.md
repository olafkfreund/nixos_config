---
status: draft
issue: 2291
author: olafkfreund
---

# Intent: Claude can hand implementation work to agy

## Problem

Claude reaches Antigravity in only one way: the `second-opinion` skill,
which runs `agy --mode plan` for read-only review. That works. A probe on
p620 (agy 1.3.4, 2026-10-14) returned `AGY_OK` in 37 s.

Handing agy a job to implement does not work, and it fails silently:

- `agy-implement` (from #2087) was built for a session you start and drive
  yourself. Claude can only run it headless (`-p`).
- Headless agy cannot ask for permission, so it denies every shell command.
  In the probe, agy was told to append a line to a file and then try
  `git commit`. It made no edit, exited 0 and reported
  `"status":"SUCCESS"` with an empty response. The only clue was this line
  on stderr:
  *"a tool required the "command" permission that headless mode cannot
  prompt for, so it was auto-denied. Add an allow-rule under
  permissions.allow in settings.json."*
- A caller that checks the exit code or `status` concludes the job was done.
- Nothing tells Claude how to make the handoff. The `second-opinion` skill
  says implementing is `agy-implement`'s job and stops there. `AGENTS.md`
  describes `agy-implement` and `codex-implement` only as sessions you start.

What exists and can be reused:

- **The guard.** The shared coder guard is already registered for
  `agy-implement` in `~/.gemini/config/hooks.json` and is gated on
  `AGY_CODER=1`. It blocks commits, deploys, restarts, garbage collection
  and reboots.
- **A managed settings layer.** agy reads `/etc/antigravity/admin_settings.json`
  (the path is in the 1.3.4 binary). We do not set that file today. It lives
  outside the Syncthing-synced `~/.gemini`.
- **The permission format.** The binary's own examples of allow-rules
  include `command(git status)`, `command(<prefix>)`, `command(*)`, `file(*)`
  and `mcp(*)`.

## Proposed outcome

- **Claude can hand over a job.** Claude passes `agy-implement` an
  approved `plan/` step in a task worktree. agy edits files and runs the
  commands the step needs (build, eval, format, tests) without a prompt.
  It returns, and Claude reviews the diff and commits, as with the `coder`
  subagent.
- **Same limits as today.** No commits, deploys, restarts, garbage
  collection or reboots. The guard still blocks them, and a live probe
  shows it does so headless too.
- **A failed handoff is reported as failed.** An empty response, a
  permission denial or a timeout counts as "not done", never as success.
- **Review stays read-only.** `second-opinion` and plain `agy` behave
  exactly as now.
- **The rules match.** `AGENTS.md`, the skill Claude follows, and the
  Antigravity global rules all describe the handoff path.
- **Proven end to end.** On p620 and razer, a scratch handoff edits a file
  and runs a build, then has its `git commit` blocked by the guard's own
  message.

## Affected users and systems

- **agy configuration:** `home/development/antigravity-config.nix` (the
  `agy-implement` wrapper and the hook registration). It may also need a new
  NixOS-managed `/etc/antigravity/admin_settings.json`.
- **Rules and skills:** `AGENTS.md` ("Delegating to other models"), the
  `second-opinion` skill or a new handoff skill, and
  `home/development/agent-rules/agy-standards.md`.
- **Hosts:** p620 and razer. p510 only with your approval.

## Constraints

- **Allow only what the job needs.** The guard must not be the only thing
  standing between agy and the host. If the allow-list can only be global,
  it must not widen what plain `agy` or `--mode plan` may do.
- **No `--dangerously-skip-permissions`.** It stays banned, including inside
  wrappers.
- **Syncthing.** Nothing goes into `~/.gemini` as a Nix store symlink on a
  synced path.
- **Subscription login only** (#1831).
- **One implementer per task, in its own worktree.** Never the shared
  `~/.config/nixos` checkout.
- **Claude keeps the deciding and the committing.** agy's output is
  untrusted until Claude reviews it.

## Open questions

1. **Who may start it.** `AGENTS.md` currently says `agy-implement` runs
   only in a session you start. Do you approve Claude starting it headless
   for an approved `plan/`? Should that also cover `codex-implement`, which
   has the same "user starts it" wording?
2. **When Claude hands to agy.** Is it only when you say so ("give this to
   agy"), or also by default for large plans in place of the Sonnet `coder`
   subagent? The managed policy currently names `coder` for plans of three
   or more steps.
3. **How wide the allow-list is.** Should it be a fixed list of commands
   (`nix build`, `nix eval`, `nix fmt`, `just check-syntax`, `git diff`,
   `git status`, read tools), or broader with the guard as the backstop? The
   proposal is a fixed list, widened when a real task needs more.
4. **Model.** Keep `gemini-3.8-flash-medium` from #2087, or let Claude pick
   per task with `--model`?
