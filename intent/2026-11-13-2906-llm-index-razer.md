---
status: approved
issue: 2906
author: olafkfreund
---

# Intent: llm-index on razer as well as p620

## Problem

llm-index runs only on p620 (#2882, #2899, #2904). The owner wants the same
setup on razer: `~/Source` searchable by Claude Code, Codex and agy through
the public MCP server, `~/Documents` indexed privately.

`hosts/common/nixos/llm-index.nix` cannot be imported on razer as it is:
it hard-codes p620's real source path, `/mnt/code/Source-home`. On razer
`~/Source` is a symlink to `/extdisk/Source` (ext4 on the second NVMe,
mounted from fstab), and llm-index refuses a root path with a symlink
component.

Facts checked on razer (2026-11-13): kernel 7.3.1, Landlock ABI 11, 62 GB
RAM; `/extdisk/Source` is 122 GB with about 870k files before the built-in
skips; `~/Documents` is a real path, 963 MB and 7.1k files.
`/extdisk/Source/password` is a 9-byte file with no extension; it is not
an indexed file type, but it must never reach the public tier.

## Proposed outcome

- razer runs `llm-index.service` with `source` = `/extdisk/Source`
  (public) and `docs` = `~/Documents` (private), the same tiers and limits
  as p620; both roots reach `ok`.
- `/extdisk/Source/password` is excluded explicitly.
- On razer, Claude Code, Codex and agy each find results through the
  public server; nothing from `~/Documents` is returned there.
- razer also gets the llm-index agent instructions
  (`~/.claude/rules/llm-index.md`, and the Codex and agy `AGENTS.md`
  sections gated on the service), as p620 has; the stale "p620 only"
  comment in `home/development/agent-rules.nix` is corrected.
- p620's configuration and behaviour do not change.

## Affected users and systems

- razer (laptop, owner's) and p620. Not p510.
- The synced `~/.gemini/config/mcp_config.json`: at the same `flake.lock`
  both hosts produce a byte-identical `llm-index` entry (same package, and
  `--config` names the stable `~/.config/llm-index/config.toml`, not its
  per-host store target). The entry differs only briefly while one host
  runs a newer llm-index than the other. p510 stays in that sync group
  without llm-index, harmless as since #2882.

## Constraints

- Each host's source path and any host-specific exclusion are set in that
  host's config; the shared module keeps no host-specific path. (An
  exclusion must lie under one of the host's roots, so razer's `password`
  exclusion in the shared module would fail p620's evaluation.)
- The public tier never includes `~/Documents` or the excluded file.
- Validate before deploying (test builds of both hosts and CI). Deploy
  razer through the repo's route for heavy razer rebuilds, the
  `deploy-via-p620` recipe (build on p620, switch on razer), from `main`
  after announcing on the agent bus; razer must be reachable. p620 is
  rebuilt to confirm it is unchanged.
- The first index on razer is large; the service's memory cap (2 GB) and
  low CPU and I/O priority stay as on p620.

## Open questions

- razer is a laptop: the first index of about 870k files runs at idle
  priority and may take longer on battery. Proposed: accept; no
  battery-specific setting.
