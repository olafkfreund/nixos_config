---
status: draft
issue: 2906
intent: intent/2026-11-13-2906-llm-index-razer.md
---

# Spec: llm-index on razer as well as p620

## Design

1. **Per-host options in the shared module** (`hosts/common/nixos/llm-index.nix`).
   Add, following the repo's `local.*` convention for host settings in
   shared modules:

   - `options.local.llmIndex.sourcePath`: `types.str`, no default, so a host
     that imports the module must set it. Description: real path of the
     public `source` root (no symlink component).
   - `options.local.llmIndex.excludePaths`: `types.listOf types.str`,
     default `[ ]`. Passed to `services.llm-index.exclude.paths`.

   The module's `home-manager.users.olafkfreund` block reads them from the
   NixOS `config` (the module's outer function gains `config` and `lib`)
   and sets `roots.source.path = sourcePath` and `exclude.paths =
   excludePaths`. Everything else (tiers, `registerPublic = false`,
   `memoryMaxMb = 2048`, the activation that registers Claude Code, Codex
   and agy, the Claude rules file) stays as it is.

2. **p620** (`hosts/p620/nixos/nixarchy.nix`): keep the import and set
   `local.llmIndex.sourcePath = "/mnt/code/Source-home";` with the
   existing comment (real path; `~/Source` is a symlink). p620's evaluated
   `services.llm-index` config must be identical to today.

3. **razer** (`hosts/razer/nixos/nixarchy.nix`): import
   `../../common/nixos/llm-index.nix` and set
   `local.llmIndex.sourcePath = "/extdisk/Source";` (comment: real path;
   `~/Source` is a symlink, `/extdisk` is the second NVMe from fstab) and
   `local.llmIndex.excludePaths = [ "/extdisk/Source/password" ];`.

4. **Comment fix** (`home/development/agent-rules.nix:8`): "p620 only"
   becomes "hosts that import hosts/common/nixos/llm-index.nix (p620,
   razer)".

## Alternatives rejected

- **Override `roots.source.path` with `lib.mkForce` in razer's config.**
  Leaves p620's path in the shared module and hides which host wins.
- **A `hosts/razer/variables.nix` entry.** Variables there feed many
  modules; a module option keeps the setting next to the module that uses
  it and fails at evaluation when missing.
- **Put the exclusion in the shared module.** It must lie under a root of
  the host; on p620 it would fail the module's assertion.

## Risks

- razer's first index (about 870k files before skips) takes a while and
  runs at idle priority; memory is capped at 2 GB.
- An evaluation error if a future host imports the module without
  `sourcePath`: intended, the message names the option.
- razer unreachable at deploy time: the deploy waits; p620 is not
  affected.

## Verification

- `nix build .#nixosConfigurations.p620.config.system.build.toplevel`
  and the same for razer; `nix eval` of p620's
  `home-manager.users.olafkfreund.services.llm-index.roots` and `.exclude`
  equals the value on `main`.
- CI on the PR (p620, razer, p510 configurations).
- razer after deploy:
  - `systemctl --user is-active llm-index`; the self-test journal lines
    (sockets and signal denied, `dumpable=false`/`true`);
  - `llm-index status`: `source` and `docs` reach `ok`;
  - Claude Code, Codex and agy each return a hit from `/extdisk/Source`;
  - a public `search` with `folder` set to `~/Documents` returns nothing,
    and `get` on `/extdisk/Source/password` returns `not found`.
- p620 after its rebuild: service unchanged and a search still works.
