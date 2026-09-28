---
status: approved
issue: 2052
author: olafkfreund
---

# Intent: an unmerged branch cannot reach a host by accident

## Problem

`/etc/nixos` is a symlink to `~/.config/nixos`, the one checkout that the
user and every agent share. Agents switch branches inside it and leave it
there. Any deploy that builds from the checkout then ships that branch.

On 2026-09-27, p620 was switched twice (generations 2663 at 19:19 and 2664
at 20:05) from `feat/rdp-between-hosts`, an agent's branch that had never
been pushed. It brought in `hypr-rdp`, which crash-looped every 5 s on
Hyprland 0.56 (nixarchy#1031). Each loop rebuilt every bar, the Omarchy shell
eventually crashed, and the recovered instance had dead IPC. The fix was a
manual redeploy of p620 from main.

The same habit caused the stray commit in #2033 and made `nhs` refuse to run
on 2026-09-25.

Only one deploy path checks the branch:

| Path | Builds from | Branch check |
| --- | --- | --- |
| Nightly `nixos-upgrade` | `github:olafkfreund/nixos_config` | not needed |
| `nhs` / `scripts/update-commit-deploy.sh` | checkout | refuses non-main (line 89) |
| `just p620`, `razer`, `p510`, `quick-deploy`, `emergency-deploy`, and other `Justfile` deploy recipes | `.#host` | none |
| Raw `nixos-rebuild` / `nh os` on `/etc/nixos` or `.` | checkout | none |
| nixarchy's rebuild button, `nixarchy-apply` (`NIXARCHY_FLAKE=/etc/nixos`) | checkout | none (lives in the nixarchy repo) |

## Proposed outcome

- Agents never check out a branch in `~/.config/nixos`. Branch work happens in
  a `git worktree`. For Claude Code this is enforced; for Codex and
  Antigravity it is a written rule in `AGENTS.md`.
- Every deploy recipe in this repo refuses to build a branch other than
  `main`, unless the caller opts in explicitly for that one run. Deploying a
  PR branch to razer on purpose must stay possible.
- A deploy prints the branch and commit it is building.

## Affected users and systems

- Agents: Claude Code (hook), Codex and Antigravity (`AGENTS.md`).
- The user: the `Justfile` deploy recipes gain a branch check with an
  opt-in override.
- Files: `AGENTS.md`, `Justfile`, `modules/programs/claude-code-managed.nix`,
  `scripts/update-commit-deploy.sh` (its check becomes the shared one).
- Hosts: the hook ships through the managed module on p620, razer and p510.
  p510 is only evaluated unless the user asks.

## Constraints

- Deploying a non-main branch on purpose stays possible, with one visible
  opt-in, like `P510_DEPLOY_APPROVED=1` in the existing p510 guard.
- The hook matches command text, and prose trips it (see the bus guard). It
  must not block read-only git (`status`, `log`, `diff`, `worktree add`).
- No change to the nightly `nixos-upgrade`, which is already safe.
- p510 is never deployed without asking.

## Open questions

1. **The nixarchy paths** (rebuild button, `nixarchy-apply`) need the same
   check upstream. Should I file a nixarchy issue as part of this task, or
   leave it?
2. **The hook's door:** a Claude session that genuinely needs a branch in
   the shared checkout (for example, the user asks for it) passes an
   explicit variable, like the p510 guard. Or should it be a hard block with
   worktrees as the only route?
3. **Plain `git checkout <file>`** (restoring a file) must stay allowed. Only
   switching branches is blocked. Agreed?
