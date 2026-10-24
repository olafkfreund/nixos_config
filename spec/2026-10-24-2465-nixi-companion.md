---
status: draft
issue: 2465
intent: intent/2026-10-24-2465-nixi-companion.md
---

# Spec: nixi's snowflake companion runs on p620 and razer

## Design

- Add `companion.enable = true;` to the existing `services.nixi = { … };`
  block in:
  - `hosts/p620/nixos/nixarchy.nix` (about line 169);
  - `hosts/razer/nixos/nixarchy.nix` (about line 145).

  It sits beside `watcher.enable`, with a one-line comment.
- nixarchy defaults `services.nixi.companion.package`
  (`modules/home.nix:882`, #1438), and nixi's module asserts that it is set
  (`nix/hm-module.nix:285`). So the package needs nothing from us.
- Run `nix flake update nixarchy`, which moves the edge pin to one that
  contains nixarchy 0ca68d97 (#1438).

## Alternatives rejected

- **A `features.*` wrapper.** This is a Home Manager option of nixi's
  module, set inside the existing block, the same as `watcher.enable` beside
  it. A wrapper adds nothing.
- **Pinning nixarchy to a commit for this.** The hosts follow edge by
  design.

## Risks

- **The edge bump carries other changes since 3161f338.** These are
  nixarchy's own edge commits: nixi tracking master and #1433/#1435.
  Edge's own `verify` passed them.
- **The p620 switch restarts the CI runners.** Gate it on no CI in flight.
- **The companion pulls in the nixoarchy-snowflake fork** (a Void fork),
  which is new closure on both hosts. Build first.

## Verification

- `nix eval` of
  `.#nixosConfigurations.<host>.config.home-manager.users.olafkfreund.services.nixi.companion.enable`
  prints `true` for both hosts.
- Both `system.build.toplevel`s build: p620 locally, razer on p620.
- After the switch:
  - `nixi-companion` is on PATH for the user;
  - the theme hook exists at `~/.config/omarchy/hooks/theme-set.d/nixi-companion`.
