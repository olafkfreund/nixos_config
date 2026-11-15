---
status: approved
issue: 2932
author: olafkfreund
---

# Intent: move duplicated host configuration into shared files

## Problem

`hosts/{p620,razer,p510}/configuration.nix` are 690-960 lines each, and much of that is the same text repeated:
`hosts/templates/desktop.nix`, which all three import, sets only four defaults. The same imports, feature blocks,
display-manager settings, package lists and services appear two or three times (map: Fable review on
`5a01ce4c8`, e.g. the five `hosts/common/nixos` imports, `features.security`/`syncthing`, the whole
`features.ai.mcp` block, the GStreamer list). `hosts/{p620,razer}/nixos/nixarchy.nix` copy the same 30-line import
list. A change to shared behaviour has to be made in two or three places and drifts when one is missed.

## Proposed outcome

Shared configuration lives once: in the template (all three hosts), in one fragment for the two interactive hosts
p620 and razer, and in one Omarchy import list. Each host file keeps only what is specific to that machine. Every
host builds exactly the same system as before.

## Affected users and systems

`hosts/` only; p620, razer, p510. No runtime change.

## Constraints

- Behaviour-preserving: `scripts/config-snapshot.sh` `IDENTICAL` on all three hosts against `main`.
- Never `mkDefault` a list a host also sets (it would be dropped, not merged); leave `nixpkgs.config`,
  `users.users`, `age.identityPaths`, signing keys, firewall and GPU settings per host.
- AGENTS.md: services stay in `modules/`; `hosts/common/nixos/` holds host-composition fragments (imports and
  settings), which is what this adds.

## Open questions

None.
