---
status: draft
issue: 1894
intent: intent/2026-09-18-1894-nixarchy-distrobox-plugin.md
---

# Spec: install the nixarchy-distrobox plugin on p620 and razer

## Decisions taken from the intent's open questions

The owner approved the intent with its defaults:

1. **The pending `flake.lock` bump of `nixarchy-pkg`** (someone else's, and
   uncommitted) stays **out of this branch**. It is stashed before this task
   touches `flake.lock` and restored afterwards, untouched.
2. **No keybind.** A comment names the free chord, `SUPER + ALT + D`, the way
   the nixarchy-pkg wiring names its own.
3. **razer is enabled over SSH after its deploy**, with
   `omarchy plugin enable nixarchy.distrobox`.

## Facts checked for this spec

- Both host files take `inputs` as a module argument
  (`hosts/p620/nixos/nixarchy.nix:11`, `hosts/razer/nixos/nixarchy.nix:11`).
  The nixarchy-pkg lines, `hosts/p620/nixos/nixarchy.nix:140` and
  `hosts/razer/nixos/nixarchy.nix:113`, are the template.
- podman is enabled on both hosts (`hosts/p620/nixos-options.nix:35`,
  `hosts/razer/nixos-options.nix:32`). The distrobox module reaches both
  users. Checked on razer over SSH: `distrobox` and `podman` are on the user's
  `PATH`, and `omarchy-shell` is present.
- **razer** has nothing at `~/.config/omarchy/plugins/nixarchy.distrobox`, so
  the link can be created.
- **p620** has a real directory there (the development copy), which nixarchy
  refuses to replace.
- The plugin flake's package passes `omarchy plugin validate`, and its own
  checks pass at the merge commit `7e2a532`.

## Design

### 1. `flake.nix`: the input

Add it directly after the `nixarchy-pkg` block (`flake.nix:120-131`), with a
comment in the same shape:

```nix
    # nixarchy-distrobox: distrobox on the Omarchy bar and a key -- list,
    # create (every distrobox create flag), enter, start, stop, upgrade and
    # delete boxes, with create and upgrade streamed into the panel. QML only;
    # its closure is the plugin files, and it runs distrobox and podman from
    # PATH.
    #
    # Nix installs the plugin; enabling it is runtime state in shell.json and
    # deliberately not managed here, so each machine needs one:
    #   omarchy plugin enable nixarchy.distrobox
    nixarchy-distrobox = {
      url = "github:olafkfreund/nixarchy-distrobox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

`flake.lock` gets a new node for this input from `nix flake lock` (the
command only adds missing inputs). The pending `nixarchy-pkg` bump is stashed
first, so the committed lock contains only the new node.

### 2. `hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`

Both hosts get the same block, directly after the `nixarchy.pkg` one:

```nix
    # nixarchy-distrobox: the Omarchy panel for distrobox boxes. Installed,
    # not enabled -- once per machine:
    #   omarchy plugin enable nixarchy.distrobox
    # SUPER+ALT+D is free in Omarchy's set, if you want it on a key:
    #   omarchy-shell shell toggle nixarchy.distrobox '{}'
    programs.nixarchy.plugins."nixarchy.distrobox".src =
      inputs.nixarchy-distrobox.packages.${pkgs.stdenv.hostPlatform.system}.default;
```

### 3. The rollout

Neither host has the plugin as a store link yet, and p620's development copy
is in the way. The order:

1. Build-test both hosts before anything is removed or deployed.
2. **p620**
   1. Remove the development copy.
   2. Deploy.
   3. Confirm the path is now a store link, and that the widget came back
      without being enabled again.
3. **razer**
   1. Deploy through p620.
   2. Enable the plugin over SSH.
   3. Restart its shell.
4. Restore the stashed `nixarchy-pkg` lock bump to the working tree.

## Alternatives rejected

- **A Home Manager module in the plugin repository.** The intent's
  constraint: nixarchy's own `programs.nixarchy.plugins` option already
  validates and links plugins. Every sibling plugin uses it.
- **Enabling in Nix** (writing `shell.json`). nixarchy deliberately leaves
  `shell.json` to the user. The nixarchy-pkg wiring follows that rule.
- **Committing the pending `nixarchy-pkg` bump here.** It is not this task's
  change, and it would muddle review and rollback. Decision 1 above.
- **Adding p510.** The repo rule is no p510 build or deploy without asking
  first, and the intent scopes it out.

## Risks

- **p620, the development copy.** If the switch fails after the copy is
  removed, the widget is gone until the next good switch. It comes back by
  itself with no other action, because `shell.json` keeps
  `{"id":"nixarchy.distrobox"}`. The build-test before the removal is the
  mitigation. A copy of the directory is kept in the task's scratch space
  until p620 is confirmed.
- **razer, build load.** It is a heavy host, so the build goes through
  p620, as the repo requires.
- **A lock conflict when restoring the stash.** The new input adds a node and
  a root entry. The pending bump changes the `nixarchy-pkg` node, a different
  hunk, so the stash should reapply cleanly. If it does not, it stays in
  `git stash` untouched, and that is reported instead of resolved blindly.
- **A new flake input on `main`.** The CI gate job treats this as a change
  that can affect p620, razer and p510 evaluation. p510's configuration does
  not reference the input, so p510 does not change.

## Verification

- `just validate`, `just test-host p620` and `just test-host razer` succeed.
  `nix eval` shows the p510 system unchanged.
- **After deploying p620:**
  - `readlink ~/.config/omarchy/plugins/nixarchy.distrobox` resolves into the
    Nix store;
  - `omarchy shell nixarchy.distrobox.bar status` answers;
  - the glyph is on the bar;
  - `qs log` shows no plugin errors.
- **After deploying razer:** the same checks over SSH, plus
  `omarchy plugin enable nixarchy.distrobox`, then
  `omarchy-shell shell toggle nixarchy.distrobox '{}'` shows the menu layer
  in `hyprctl layers -j`.
- `git stash list` is empty and `flake.lock`'s `nixarchy-pkg` bump is back
  in the working tree.
