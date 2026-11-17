---
status: draft
issue: 3047
author: olafkfreund
---

# Intent: deploy guards catch the script path and allow dry runs

## Problem

Two PreToolUse guards in `modules/programs/claude-code-managed.nix` stand between Claude Code and a disruptive
command: the bus-announce guard (announce on `#agents` first) and the p510 guard (no p510 deploy without the
owner's OK). Both match command text. A read-only Codex review during #3039 found two gaps:

1. **The update script itself is not recognised.** `nhs` and `just update-commit-deploy` are wrappers around
   `scripts/update-commit-deploy.sh`. Calling the script directly (`bash scripts/update-commit-deploy.sh p510`,
   `./scripts/update-commit-deploy.sh razer`) deploys exactly like `nhs`, but neither guard fires: the bus guard
   matches `nhs`, `just …` recipe names and `nixos-rebuild`/`nh os` text, and the p510 guard likewise. So a p510
   deploy can run without the owner's OK, and any deploy without an announcement.
2. **A dry run is treated as a deploy.** `just --dry-run razer` (or `-n`) only prints the recipe, but the bus guard's
   `just` pattern allows option words before the recipe name, so it demands an announcement. That pushes agents
   toward writing check commands into files to get past the guard, which hides what they run.

## Proposed outcome

- Running `update-commit-deploy.sh` in any form (`bash scripts/…`, `./scripts/…`, an absolute path) is treated like
  `nhs`: the bus guard requires the announcement, and the p510 guard requires `P510_DEPLOY_APPROVED=1` when the host
  argument is p510. Its `--no-deploy` mode is treated the same way `nhs` treats it today.
- `just --dry-run …` / `just -n …` passes both guards without an announcement, and so does `just --list`/`--show`.
- Everything blocked today stays blocked.

## Affected users and systems

- `modules/programs/claude-code-managed.nix` (both guards), `scripts/test-bus-guard.py`,
  `scripts/test-p510-deploy-guard.py`.
- Claude Code sessions on p620, razer and p510 (the guards are deployed with the system).
- Not the coder guard (`modules/programs/claude-coder-guard.sh`), which already blocks the script by name.

## Constraints

- Never weaken a block: only the read-only dry-run/list/show forms are newly allowed, and only when no other part of
  the command is disruptive (`just -n razer && just razer` must still be blocked).
- No false negatives through quoting, `bash -c`, `env VAR=…`, `sudo`, or an absolute path.
- Tests for every new allowed and blocked form in the existing Python test scripts; `just test-guards` passes.
- Deploying the guard change means a p620 switch (and razer); p510 only with the owner's OK.

## Open questions

1. Should `--no-deploy` (`nhsb`, build only) still need an announcement? Recommended: keep today's behaviour for
   `nhs --no-deploy`, whatever it is, so the script and its wrapper behave the same.
2. Should `just --evaluate`/`--summary` also be allowed? Recommended: yes, they are read-only like `--list`.
