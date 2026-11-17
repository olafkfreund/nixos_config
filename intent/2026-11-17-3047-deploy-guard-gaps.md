---
status: draft
issue: 3047
author: olafkfreund
---

# Intent: deploy guards catch the script path, quoted forms, and allow dry runs

## Problem

Two PreToolUse guards in `modules/programs/claude-code-managed.nix` stand between Claude Code and a disruptive
command: the bus-announce guard (announce on `#agents` first, lines ~536-560) and the p510 guard (no p510 deploy
without `P510_DEPLOY_APPROVED=1`, lines ~363-380). Both match command text. Read-only reviews during #3039 and of
this intent found three gaps, each reproduced by feeding text to the guards:

1. **The update script itself is not recognised.** `nhs` and `just update-commit-deploy` wrap
   `scripts/update-commit-deploy.sh`. `bash scripts/update-commit-deploy.sh p510`, `./scripts/…` or an absolute path
   pass both guards. On p510 itself the script with no host argument also passes: it defaults HOST to `hostname`.
2. **Quoted and subshell forms slip through.** `'nhs' p510`, `"nhs" p510`, `bash -c 'nhs p510'`, `(nhs p510)` and
   `just 'p510'` pass both guards: the `nhs` pattern needs whitespace or line start before the name, and the recipe
   pattern expects an unquoted name.
3. **Inspection commands are treated as deploys.** Because both `just` patterns skip any option word before the
   recipe name:

   | Command | Bus guard | p510 guard |
   | --- | --- | --- |
   | `just --dry-run razer` | deny | allow |
   | `just -n p510` | deny | deny |
   | `just --show p510` | deny | deny |
   | `just --list p510` | deny | deny |

   This pushes agents to put check commands in files to get past the guard, which hides what they run.

## Proposed outcome

- `update-commit-deploy.sh` in any of the forms above is treated like `nhs` by both guards, including with no host
  argument when the guard runs on p510.
- The listed quoted and subshell forms of `nhs` and `just <host>` are caught.
- `just -n`/`--dry-run`, `--show` and `--list` with a guarded recipe name pass both guards, judged per invocation:
  `just -n razer && just razer` is still blocked.
- Everything else blocked today stays blocked.

## Affected users and systems

- `modules/programs/claude-code-managed.nix` (both guards), `scripts/test-bus-guard.py`,
  `scripts/test-p510-deploy-guard.py`.
- Claude Code sessions on p620, razer and p510 (the guards ship with the system).
- Not the coder guard, which already blocks the script by name.

## Constraints

- Only the inspection forms above are newly allowed; nothing else gets weaker.
- The guards match text; they cannot follow arbitrary shell evaluation (variables, `eval`, functions defined in the
  same command). The promise is the literal forms listed here, each with a test.
- Tests for every new allowed and blocked form in the existing Python test scripts; `just test-guards` passes.
- Deploying the change means a p620 switch (and razer); p510 only with the owner's OK.

## Open questions

Today `nhs --no-deploy p510` is denied by both guards; `nhsb p510` (which calls `just update-commit`, not the
script) passes both. `--no-deploy` is not read-only: it updates the lock, builds, commits, pushes and opens a PR.

1. Script with `--no-deploy`: same as `nhs --no-deploy` today (announce, and p510 approval for p510)?
   Recommended: yes, matching the wrapper.
2. Should `nhsb` / `just update-commit` then also need an announcement, since it pushes and opens a PR?
   Recommended: no, out of scope here: it does not touch a host. Leave it as it is.
3. Allow `just --evaluate` and `--summary` too? Recommended: no for now; only the forms whose read-only behaviour is
   verified (`-n`, `--dry-run`, `--show`, `--list`).
