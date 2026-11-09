---
status: approved
issue: 2812
author: olafkfreund
---

# Intent: run agy and Codex unrestricted, everywhere

## Problem

The owner wants agy and Codex to do real coding and make changes with no permission prompts and no sandbox, on
every launch path. What stands in the way today:

- **The rule.** `AGENTS.md:84`: "never pass `--dangerously-skip-permissions` to plain `agy`, `--mode plan` or
  Codex". The `second-opinion` and `handoff` skills repeat it.
- **The wrappers.** Every launch path Claude uses is sandboxed:
  - `agent-review` (read-only, Codex only);
  - `agent-implement` (worktree-only writes, no secrets, no Nix daemon, read-only `.git`);
  - `agent-env` (allow-listed environment).

  `agent-review.sh:78` and `agent-implement.sh:98` refuse `--dangerously-*` from callers. `agy-implement` passes
  `--dangerously-skip-permissions` itself, inside the sandbox, behind its guard.
- **The failures.** agy's headless `--mode plan` reviews auto-deny any shell command that is not in
  `antigravity-config.nix:94`'s allow-list. That happened three times on 2026-11-09, with "jetski: no output
  produced — a tool required the "command" permission that headless mode cannot prompt for".

## Owner decisions (2026-11-09)

1. "we can use that "--dangerously-skip-permissions" for agy as well as codex give them the ability to do actual
   coding and making changes".
2. Where: "Everywhere, no sandbox".
3. Which launch paths: "Everything Claude starts". That covers the owner's own sessions, Claude's delegated
   reviews, delegated implementation and the #2810 herdr team members.

## Proposed outcome

- **agy:** every launch path runs with `--dangerously-skip-permissions`.
- **Codex:** every launch path runs with `--dangerously-bypass-approvals-and-sandbox`. That is no approvals and
  no Codex sandbox, unlike `-a never`, which keeps the sandbox.
- **Wrappers:** the sandbox wrappers are no longer on any launch path that Claude uses. `second-opinion`,
  `handoff`/`agent-run` and #2810's `herdr-team` start the tools directly. The wrappers stay in the repo, unused
  by default, so going back is a revert.
- **Docs:** `AGENTS.md`, the skills and the docs describe the new rule. The old ban text is gone.
- **#2810:** gets Amendment 2. Its members run unrestricted, which replaces the approved "no herdr socket"
  guarantee. The `notify` capture and pointer-only typing still work, but nothing stops a member from writing turn
  files or using the socket.

## Affected users and systems

- **People:** the owner, and every Claude Code session on p620, razer and p510.
- **Files:** `AGENTS.md`, the `second-opinion` and `handoff` skills, `agent-run.sh`, the launchers in
  `codex-cli.nix` and `antigravity-config.nix`, #2810's `herdr-team.sh` and its docs, and
  `modules/programs/claude-code-managed-claude.md`.

## What becomes instruction-only

The owner accepts every item below. Each is enforced today and becomes a rule the model is only asked to follow.

| Today it is enforced by | After this change |
| ----------------------- | ----------------- |
| No secrets in the sandbox (`agent-env`, the tmpfs `/home`) | SSH keys, `~/.config/gh`, agenix paths readable by the user, and the GitHub token in a login shell's `NIX_CONFIG` are all reachable |
| No herdr socket | Any agent can type into any pane, including Claude's, and answer its permission prompts |
| Read-only `.git` for implementers | An agent can commit, push, rewrite history and change the shared checkout `~/.config/nixos` (`/etc/nixos`) |
| No Nix daemon socket | An agent can build. On p510, where `olafkfreund` is still a trusted Nix user (#2758), it can import unsigned paths |
| Sandboxed network and filesystem | An agent can reach p510 and razer over SSH, restart services, deploy, and run garbage collection |

Rules that stay, as instructions: Claude alone commits, deploys and reboots; the bus announcement before
disrupting a shared host; p510 is never built or deployed without asking; worktrees, never `main`; subscription
login only (#1831); agent output is advice and never approves an intent, spec or plan.

## Constraints

- Every change is a revert away. The wrappers and their tests stay in the repo.
- `HUMANIZE_CODEX_BYPASS_SANDBOX` (the humanize plugin's own path) is not part of this, and stays forbidden.
- Hosts: the same rule on p620, razer and p510.

## Open questions

None. The owner decided the scope above.
