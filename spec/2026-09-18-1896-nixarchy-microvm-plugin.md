---
status: draft
issue: 1896
intent: intent/2026-09-18-1896-nixarchy-microvm-plugin.md
---

# Spec: install the nixarchy-microvm plugin and its SUPER+ALT+V bind on p620 and razer

## Decisions taken from the intent's open questions

The owner approved the intent with its defaults:

1. **Input ref.** The input tracks `main` of `olafkfreund/nixarchy-microvm`.
   Nothing here is deployed until that repository's PR (#1) is merged.
2. **The uncommitted changes stay out of this branch.**
   - The `nixarchy-voice` lock bump is stashed before `nix flake lock` and
     restored afterwards.
   - The staged `p1` test lines are dealt with by precondition 1 below.
3. **razer is set up over SSH after its deploy.** Two actions:
   `omarchy plugin enable nixarchy.microvm`, and the one `pcall` line in its
   `bindings.lua`.
4. **The microvm service stays off on razer.**

## Facts checked for this spec

- `programs.nixarchy.plugins` is a Home Manager option. On both hosts the
  existing plugin lines sit inside `home-manager.users.olafkfreund`
  (`hosts/razer/nixos/nixarchy.nix:121`, `hosts/p620/nixos/nixarchy.nix:148`).
- `hosts/common/nixos/omarchy-ai-mirror.nix` is the pattern for a plugin
  that also brings a Home Manager module and a bind fragment. It is imported
  by p620 and razer (`nixarchy.nix:33` on each).
- The plugin flake at `feat/1-microvm-plugin` (`d5b3e40`) provides:
  - `packages.<system>.default`, which passes `omarchy plugin validate`;
  - `homeManagerModules.default`, which writes
    `~/.config/hypr/microvm-binds.lua` from
    `programs.nixarchy-microvm.keybinding` (default `SUPER + ALT + V`, chord
    only, `null` = none).
- **p620:**
  - a development copy is a real directory at
    `~/.config/omarchy/plugins/nixarchy.microvm`;
  - a hand-written `~/.config/hypr/microvm-binds.lua` exists;
  - `bindings.lua` already has `pcall(require, "hypr.microvm-binds")`.
  `hyprctl binds` and Super+K both show `SUPER ALT + V → MicroVMs`.
- **razer**, checked over SSH:
  - there is no plugin directory and no `microvm-binds.lua`;
  - `bindings.lua` has three `pcall(require, …)` lines but not this one;
  - SUPER+ALT is bound to F, G, S, K, A, P, B, Q, Home, the arrows, TAB,
    SLASH, SPACE, comma and RETURN, plus keycodes 10-14, 20, 21, 34 and 35.
    V (keycode 55) is free.

## Design

### 1. `flake.nix`: the input

Directly after the `nixarchy-distrobox` block, in the same comment shape:

```nix
    # nixarchy-microvm: NixOS MicroVMs on the Omarchy bar and SUPER+ALT+V --
    # disposable VMs through `nixarchy vm` and permanent ones through
    # programs.nixarchy.services.microvm, created, edited and deleted from the
    # keyboard. QML only; its Home Manager module writes the bind fragment
    # ~/.config/hypr/microvm-binds.lua (hosts/common/nixos/omarchy-microvm.nix).
    #
    # Nix installs the plugin; enabling it is runtime state in shell.json and
    # deliberately not managed here, so each machine needs one:
    #   omarchy plugin enable nixarchy.microvm
    nixarchy-microvm = {
      url = "github:olafkfreund/nixarchy-microvm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

`flake.lock` gets exactly one new node, from `nix flake lock`, run with the
voice bump stashed.

### 2. `hosts/common/nixos/omarchy-microvm.nix` (new)

This follows `omarchy-ai-mirror.nix`: one place for the plugin and its bind.
The header gives the two one-time steps per machine, because both files are
user-owned: the `pcall` line and `omarchy plugin enable`.

```nix
{ inputs, ... }:
{
  home-manager.users.olafkfreund = { pkgs, ... }: {
    imports = [ inputs.nixarchy-microvm.homeManagerModules.default ];
    programs.nixarchy.plugins."nixarchy.microvm".src =
      inputs.nixarchy-microvm.packages.${pkgs.stdenv.hostPlatform.system}.default;
    # The default chord is SUPER + ALT + V, free on both hosts (checked with
    # hyprctl binds -j). The module writes nothing when this is null.
  };
}
```

### 3. The hosts

`hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix` each
get one import line, `../../common/nixos/omarchy-microvm.nix`, after
`omarchy-ai-mirror.nix`. p510 does not import it.

### 4. The rollout

Preconditions:

1. **The plugin's live checks have finished and `p1` is gone.** Its line is
   removed from `apps.nix`, the microvm service row is back to how it was,
   and that has been applied. The staged `hosts/p620/nixarchy/*` lines then
   disappear with it. Otherwise a deploy from this tree would carry them,
   because flakes read the working tree.
2. nixarchy-microvm#1 is merged, and `nix flake lock` pins its `main`.

Order:

1. Run `just validate`, `just test-host p620` and `just test-host razer`.
2. **p620**
   1. Move the development copy and the hand-written `microvm-binds.lua` into
      the task's scratch space. Moved, not deleted, until p620 is confirmed.
   2. Deploy.
   3. Confirm both paths are store links.
3. **razer**
   1. Deploy with `just deploy-via-p620 razer`.
   2. Over SSH: `omarchy plugin enable nixarchy.microvm`.
   3. Append the `pcall` block, the same text as p620's, to `bindings.lua`.
   4. Run `hyprctl reload` and `omarchy-restart-shell` inside razer's
      session.
4. `git stash pop` the voice bump.

## Alternatives rejected

- **Per-host blocks in `nixarchy.nix`, as in #1894.** Each host would carry
  the Home Manager import as well as the plugin line, which is the
  duplication `omarchy-ai-mirror.nix` exists to avoid.
- **Writing the bind here, as `omarchy-meet-binds.nix` does.** The plugin
  owns its chord and ships it for installs without Nix too. A second copy
  here would drift from it.
- **Managing `bindings.lua` from Nix.** It is hand-written on both hosts, and
  every fragment in this repository leaves it to the user.
- **Pinning the feature branch now.** Decision 1.
- **Turning on the microvm service on razer.** Decision 4.

## Risks

- **p620's hand copies.** If the switch fails after they are moved, the
  widget and the key are gone until the next good switch. The build-test
  before the move, and keeping the moved copies, are the mitigation.
- **Home Manager's clobber check.** It refuses to write over an unmanaged
  `microvm-binds.lua`. Moving the file first is what prevents that. A failed
  activation is visible in `journalctl -u home-manager-olafkfreund`.
- **razer's session over SSH.** `hyprctl` needs the session's instance
  signature, taken from `/run/user/<uid>/hypr/`, as used for the fact check
  above.
- **Stash conflict.** The voice bump and the new input are different hunks.
  If `git stash pop` fails anyway, the stash is left in place and reported.
- **p510.** It does not import the module. Its evaluation is checked
  unchanged.

## Verification

- `just validate` and both `just test-host` runs succeed. The p510 system
  derivation is unchanged by the new input.
- **p620, after its deploy:**
  - `readlink` shows the plugin directory and `~/.config/hypr/microvm-binds.lua`
    both in the Nix store;
  - `hyprctl binds -j` has one SUPER+ALT+V bind, described "MicroVMs";
  - Super+K's record list shows it;
  - `omarchy shell nixarchy.microvm.bar status` answers;
  - `qs log` is clean.
- **razer, after its deploy:** the same checks over SSH, plus
  `omarchy-shell shell toggle nixarchy.microvm '{}'`, which shows the
  `nixarchy-microvm-menu` layer in `hyprctl layers -j`.
- `git stash list` is empty, and the voice bump is back in the working
  tree.
