---
status: draft
issue: 2929
author: olafkfreund
---

# Intent: make feature toggles control what they claim

## Problem

Several options look like switches but change nothing:

- `features.development.{languages,workflow,productivity}` (Home Manager): `home/development/{languages,workflow,productivity}.nix`
  are imported unconditionally and use their own hardcoded `let cfg = { ... }`. p510 sets `productivity = mkForce false`,
  yet obsidian, slack, discord and telegram are still installed there.
- `features.terminals.{foot,kitty,alacritty}`: `home/desktop/terminals/default.nix:11-13` hardcodes all three to `true`
  and never reads `config.{foot,kitty,alacritty}.enable` (declared at :82-84, set by `Users/common/features-impl.nix:17-20`).
  razer's `kitty = false` and p510's `terminals.enable = false` have no effect on these three.
- `aiDefaults.profile` (`modules/common/ai-defaults.nix`) and `services.syncthing.masterHost`
  (`modules/services/syncthing.nix:62`) are set on every host and read by nothing.
- `options.<lang>.development.packages` in `modules/development/{nodejs,python,go,java,lua,cargo,github,shell}.nix`
  is `listOf str` but is appended to `environment.systemPackages`, so any non-empty value would fail.
- `hosts/{p620,p510}/nixos/screens.nix` (and razer's) `import ../variables.nix` without calling it, so `vars.hostName`
  there would fail if anything read it.

## Proposed outcome

Each of these options either controls its code or is gone. **No host loses a package, unit or file:** where a toggle
was ignored, the host's value is set to what it installs today, with a comment, so the owner can now turn it off for real.

## Affected users and systems

Home Manager for `olafkfreund` on p620, razer and p510; NixOS modules above; the three host configurations.

## Constraints

- Behaviour-preserving: per host, `system.path` and HM `home.path` drvPaths identical before/after, or the difference
  explained. All three hosts built on p620 (p510 only built, never copied or switched).
- No deploy in this task.

## Open questions

None (owner approved the roadmap and chose behaviour preservation).
