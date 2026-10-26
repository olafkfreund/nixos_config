---
status: approved
issue: 2471
author: olafkfreund
---

# Intent: declarative agy read-only allow-list, and second-opinion handles empty and timed-out results

## Problem

1. **No config manages the allow-list.** In headless `-p` mode, agy soft-denies
   every shell command that has no `permissions.allow` rule. Reviews that need
   `git diff` give up. As of 2026-10-26, `~/.gemini/antigravity-cli/settings.json`
   on p620 has a hand-written list (git diff/log/show/status/rev-parse/ls-files,
   grep, rg, ls, cat, head, tail, wc, `sed -n`, find). Nothing in the repo
   writes it. `home/development/antigravity-config.nix` seeds only
   `mcp_config.json` and `hooks.json`. So the list can drift or be lost, and
   other hosts may not have it at all.
2. **The second-opinion skill counts two failures as results.**
   `home/development/claude-code-skills/second-opinion/SKILL.md` treats
   these as a review:
   - `status: SUCCESS` with an empty `.response`.
   - A run that hit `--print-timeout 10m` after spending 586 s and 408k
     input tokens rereading the repo. Callers also aren't told to name the
     files to read, which is why it reread the repo.

## Proposed outcome

- After a Home Manager activation, every host that has agy installed has
  the read-only allow-list in `settings.json`. Settings that agy or the user
  wrote stay as they are.
- A headless `agy --mode plan -p` review can run `git diff` without a
  soft-deny.
- The skill reports an empty `.response` or a timeout as "not obtained" and
  doesn't quote it as a review. Its prompt template asks the caller to list
  the files and diff to read.

## Affected users and systems

- `home/development/antigravity-config.nix`: activation script, alongside the
  MCP and hook seeding.
- `home/development/claude-code-skills/second-opinion/SKILL.md`.
- Hosts: p620, razer and p510, wherever agy runs. `~/.gemini` syncs between
  all three over Syncthing.

## Constraints

- `settings.json` is mutable: agy writes `model`, `statusLine` and other keys.
  It has to be merged additively with jq, like `mcp_config.json`. A
  nix-store symlink is out, because `~/.gemini` is Syncthing-synced.
- Read-only commands only. No blanket rule, and nothing that writes or
  executes.
- No change to `agy-implement` or the coder guard (#2291, #2296, #2453).
- No deploy to p510 without asking.

## Decisions (approved 2026-10-26)

1. Drop `command(find)`, which allows `-delete` / `-exec`; `rg` and `ls`
   cover it. Keep `command(sed -n)`.
2. Merge as a union: declared entries are added and entries added by hand
   stay.
