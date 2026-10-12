---
status: draft
issue: 2258
spec: spec/2026-10-12-2258-omarchy-meeting-mode.md
---

# Plan: Meeting Mode plugin on p620 and razer

Approved decisions: install `nixarchy.meeting-mode` from the flake
`github:olafkfreund/nixarchy-meeting-mode` for user olafkfreund only, on p620
and razer (not p510), exactly like `hosts/common/nixos/omarchy-pixelbuds.nix`
(#2195). Plugin defaults stay, voice pausing included. No `features.*` flag,
nothing in `modules/`. Enabling it on the bar stays a one-time manual
`omarchy plugin enable nixarchy.meeting-mode --section center`.

Work happens in the worktree `~/.config/nixos-2258` (branch
`feat/2258-omarchy-meeting-mode`). Never switch branches in `~/.config/nixos`:
it is `/etc/nixos` and deploys build whatever it has checked out (#2052).

## Steps

1. `flake.nix`, after the `nixarchy-pixelbuds` input block (lines 168-173):
   add

   ```nix
   # nixarchy-meeting-mode: quiet desktop during calls (DND, stay awake, night
   # light off, omarchy-voice stopped); hosts/common/nixos/omarchy-meeting-mode.nix.
   nixarchy-meeting-mode = {
     url = "github:olafkfreund/nixarchy-meeting-mode";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

   then `nix flake lock` → verify `git diff --stat flake.lock` touches only
   the new `nixarchy-meeting-mode` node and the root's inputs list.
   Traps: `nix flake lock`, never `nix flake update` (would bump everything).

2. New `hosts/common/nixos/omarchy-meeting-mode.nix`: copy of
   `omarchy-pixelbuds.nix` with `programs.nixarchy.plugins."nixarchy.meeting-mode".src =
   inputs.nixarchy-meeting-mode.packages.${pkgs.stdenv.hostPlatform.system}.default;`
   and a header comment: what it does during a call, that it stops
   `omarchy-voice.service` and starts it again after, and the one-time enable
   command. → verify `nixfmt --check` on the file.
   Traps: new files must be `git add`ed before eval (flakes only see tracked files).

3. `hosts/p620/nixos/nixarchy.nix:39` and `hosts/razer/nixos/nixarchy.nix:38`:
   add `../../common/nixos/omarchy-meeting-mode.nix` on the line after
   `omarchy-pixelbuds.nix`. → verify for each host
   `nix eval .#nixosConfigurations.<host>.config.home-manager.users.olafkfreund.programs.nixarchy.plugins --apply builtins.attrNames`
   includes `"nixarchy.meeting-mode"`.
   Traps: not p510.

## Tests

- Step 3's eval on p620 and razer lists `nixarchy.meeting-mode`.
- `nix build .#nixosConfigurations.p620.config.system.build.toplevel` and the
  same for razer succeed. nixarchy validates the manifest during this build
  (`validatedPlugins`), so success means the manifest is valid.
- Pre-commit hooks pass on commit.
- Manual, after deploy, per host: `omarchy plugin enable nixarchy.meeting-mode --section center`;
  `pw-record -P '{ application.name = "Google Chrome" }' /dev/null` for >3 s →
  `systemctl --user is-active omarchy-voice` prints `inactive`, indicator lit;
  Ctrl+C, wait 15 s → `active`.

## Rollback

Revert the commit (input, file, two imports) and redeploy. Before that, run
`omarchy-shell meeting-mode off` if a call is in progress, so voice and the
other settings are put back.
