---
status: approved
issue: 2019
author: olafkfreund
---

# Intent: nixarchy-menu is the menu on razer and p620, declared rather than hand-copied

## Problem

nixarchy-menu is the Raycast-style Omarchy menu replacement:
- it hands off to every default agent
- it has Nixi and skill-backed help rows
- it sizes itself to the screen

nixarchy#946 (merged as olafkfreund/nixarchy@8333f23) made it a declarable
default plugin (`programs.nixarchy.defaultPlugins.menu = true`), off unless
turned on. Neither host uses it that way yet:

- **razer** runs a **hand-copied** `~/.config/omarchy/plugins/nixarchy.menu`,
  put there by the plugin repo's own installer during testing. Nothing here
  declares, pins or rebuilds it. nixarchy leaves a real directory at a plugin
  id alone, so even with the default on, the hand copy would keep outranking
  the declared plugin until it is removed.
- **p620** runs the stock `omarchy.menu` and doesn't have nixarchy-menu.
- **The pin is too old.** This repo's nixarchy input (20b655c24 on main)
  predates 8333f23, so `defaultPlugins.menu` doesn't exist in it yet.

## Proposed outcome

- **On both hosts,** Super+Space and the bar's menu button open nixarchy-menu:
  - installed from nixarchy's pinned input
  - rebuilt with the system
  - in the stock menu's own bar slot
- **razer** has no hand-copied plugin left, and nothing outranks the declared
  one.
- **Turning it off** again, by removing the line, brings the stock menu back
  on the next login, as nixarchy#946 guarantees and razer tested.

## Affected users and systems

- **The olafkfreund user on razer and p620:** the menu itself.
- **`flake.lock`:** the nixarchy input moves forward to a commit that
  includes 8333f23. That brings in whatever else merged on nixarchy main since
  the current pin, which the spec lists.
- **Not affected:** p510, which is never built or deployed without asking.

## Constraints

- **Branch, PR, CI green before merge, and the user's go-ahead** for each
  deploy. razer is deployed with `just deploy-via-p620 razer` and claimed on
  the agent bus first. p620 deploys locally.
- **razer first, then p620.** p620 is the user's working desktop, so it
  follows only after razer checks out.
- **The live checkout stays untouched.** `~/.config/nixos` has an unrelated
  staged change (`hosts/p620/nixarchy-apps.nix`). This work happens in its
  own worktree and branch.
- **Removing razer's hand copy** is the one manual step. It's done during the
  razer deploy, and the old copy is kept as a backup until the declared
  plugin is confirmed.

## Open questions

1. Should both hosts land in one PR and one lock bump, deployed razer then
   p620? Or should there be two PRs? One PR is simpler, since the bump is
   shared.
2. nixarchy main's `build` is red on a pre-existing ledger row
   (`omarchy-shell`, nixarchy#975) that has nothing to do with the menu.
   Should the bump wait for that to go green, or pin 8333f23 now? The system
   builds either way, because the ledger is a check, not part of the build.
