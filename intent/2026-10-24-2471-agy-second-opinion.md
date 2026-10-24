---
status: draft
issue: 2471
author: olafkfreund
---

# Intent: agy second opinions work headless, and the skill tells a failure from a result

## Problem

- **Shell commands are soft-denied.** `agy -p` (headless) cannot show an
  approval prompt, so every shell command without an allow rule is
  soft-denied. The log says `permissions=<nil>, toolPermission=request-review`,
  then `Print mode: soft-denying tool confirmation "RunCommand"`.
  - A review that needs `git diff` gives up.
  - No permission rules exist: `~/.gemini/config/config.json` has none, and
    `home/development/antigravity-config.nix` manages only
    `mcp_config.json` and hooks.
- **The `second-opinion` skill
  (`home/development/claude-code-skills/second-opinion/SKILL.md`) misses
  two failure modes, both seen in ai-mirror #70/#72:**
  - A review ran 586 s, used 408k input tokens rereading the repo, and was
    cut off by `--print-timeout 10m`.
  - A review returned `status: SUCCESS` with an empty `.response`, and was
    counted as a result.

## Proposed outcome

- A headless agy review can run read-only commands (`git diff`, `git log`,
  `git show`, `git status`, `grep`, `rg`, `ls`, `cat`, `sed`, `head`, `wc`)
  without a prompt, on every host where Home Manager deploys Antigravity.
- Everything else stays soft-denied: no blanket rule, no `git` without a
  subcommand, nothing that writes.
- The skill:
  - treats an empty `.response` as "not obtained", whatever `status` says
  - tells the caller to name the files to read in the prompt
  - says how to run a long review in the background with a larger timeout

## Affected users and systems

- Home Manager on every host that imports `antigravity-config.nix`.
- The `second-opinion` skill for Claude Code sessions.
- `agy-implement` (the coder path) runs with `--dangerously-skip-permissions`
  and its own guard hook, so the allow-list does not change it.

## Constraints

- **Must not widen what agy can do.** These are read-only commands, which it
  can already run in an interactive session after a prompt.
- **Must not overwrite the user's own `config.json` settings.** Merge
  additively, the way `mcp_config.json` is seeded (existing entries win).
- **The JSON shape of agy's permission rules is not documented.** It must
  be learned from a rule agy writes itself (`/permissions` in an
  interactive session) before anything is generated.
- Never set `--mode accept-edits` or a sandbox bypass for second opinions.

## Open questions

1. **How to learn the rule shape.** Option (a) is that you add one rule
   interactively (`agy`, then `/permissions`, then `command(git diff)`
   always allow), so the spec can copy the exact JSON agy writes. Option (b)
   is that the spec tries a guessed shape and confirms it from the log.
   (a) is reliable and takes about a minute of your time. **Proposed: (a).**
2. **Scope.** All hosts where Antigravity is installed, or only p620?
   **Proposed: all,** since the rules are read-only.
