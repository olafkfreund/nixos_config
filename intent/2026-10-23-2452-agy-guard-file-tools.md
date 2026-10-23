---
status: draft
issue: 2452
author: olafkfreund
---

# Intent: agy coder guard denies agy 1.4.5's file tools

## Problem

agy 1.4.5, which arrived by auto-update in #2447, renamed its file-editing
tools: `write_file` (args `Path`, `Content`, `Overwrite`, `Append`) and
`edit_file` (args `Path`, `Target`, `Replacement`). The coder guard
(`modules/programs/agy-guard-adapter.sh`) still allows only `write_to_file`,
`replace_file_content` and `multi_replace_file_content`, and it reads the
target from `TargetFile`. Every edit an `agy-implement` session tries is
denied, so agy cannot code at all.

The guard failed closed, as designed. Nothing caught the rename before the
bump, because the post-update guard probe in the `handoff` skill is manual
and still names `write_to_file`.

Reproduced on p620 on 2026-10-23 in a scratch repo. razer runs the same agy
1.4.5 with the same guard. p510 has the module too. `agy --mode plan`
(review) and `codex-implement` both work.

## Proposed outcome

- On every host, in every agy session started through `agy-implement`, agy
  can create and edit files inside the directory it was started in. That
  includes razer and p620, and p510 when it is next deployed.
- Writes outside that directory, under `~/.gemini`, commits and sandbox
  bypasses stay blocked, exactly as today.
- The guard's tests cover the new tool names, so a future rename shows up in
  `bash agy-guard-adapter.test.sh` instead of in a failed handoff.
- The handoff skill's post-update probe uses the current tool names.

## Affected users and systems

- `modules/programs/agy-guard-adapter.sh` and its `.test.sh`, installed
  system-wide at `/etc/antigravity/hooks/coder-guard` by
  `modules/programs/claude-code-managed.nix`. All agy sessions on a host use
  that file, because `~/.gemini/config/hooks.json` is Syncthing-shared and
  points at the same `/etc` path on every host.
- `home/development/claude-code-skills/handoff/SKILL.md` (the probe text).
- Hosts: p620 (local deploy), razer (`just deploy-via-p620 razer`), p510.

## Constraints

- The guard must still fail closed: an unknown tool, or a write with no path,
  is denied.
- No new bypass. `agy-implement` keeps `--sandbox` and the hook check.
- p510 is not built or deployed without asking first.
- Announce on the agent bus before each deploy.

## Open questions

- Should the old tool names stay allowed for older agy versions, or be
  dropped? My recommendation is to keep them: it costs nothing, and the
  version on any one host can lag.
- Should p510 be deployed in this task, or left for its next routine deploy?
- Out of scope, as a separate issue: letting Claude dispatch Codex and agy
  for coding and review without being asked each time, and making
  `update-antigravity` run the guard probe automatically.
