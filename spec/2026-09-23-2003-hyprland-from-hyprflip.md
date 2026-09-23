---
status: draft
issue: 2003
intent: intent/2026-09-23-2003-hyprland-from-hyprflip.md
---

# Spec: p620 and razer run the Hyprland that hyprflip has verified

## Design

### Where the compositor comes from today

Three places decide which Hyprland a host runs:

1. `programs.hyprland.package`. nixarchy sets it at normal priority from its
   `hyprland` input (`nixarchy modules/nixos.nix:965`). The Omarchy session
   launches `${config.programs.hyprland.package}/bin/start-hyprland`
   (`nixos.nix:102`), and the SDDM greeter runs
   `${config.programs.hyprland.package}/bin/Hyprland`
   (`hosts/common/nixos/omarchy-sddm.nix:48`).
2. `hosts/common/nixos/omarchy-sole-hyprland.nix:25` hard-codes
   `inputs.nixarchy.inputs.hyprland…hyprland` for the system profile (the
   `Hyprland` and `hyprctl` on `PATH`) and for the `cap_sys_nice` wrapper
   that `start-hyprland` execs.
3. The `hyprflip` NixOS module builds against `programs.hyprland.package`
   unless `package` is set.

Items 1 and 2 must name the same build, as #1566 showed: a mismatched
`start-hyprland` and compositor broke login on razer.

### Changes

1. **`hosts/common/nixos/omarchy-sole-hyprland.nix`:**
   `hyprland = config.programs.hyprland.package;` (and add `config` to the
   arguments). The file then follows whatever package the host chose, so every
   place above agrees by construction. On p510 this is a no-op, because the
   value is still nixarchy's input.
2. **New `hosts/common/nixos/hyprland-from-hyprflip.nix`**, imported by
   p620 and razer only:

   ```nix
   programs.hyprland.package = lib.mkForce
     inputs.hyprflip.inputs.hyprland.packages.${system}.hyprland;
   ```

   `mkForce` is required because nixarchy sets the package at normal
   priority; its own comment asks for `mkForce`. The file's header comment is
   the trial record: why (#2003), the date it started, and **how to switch
   back** (below).
3. **`flake.nix`:** drop `inputs.hyprland.follows = "nixarchy/hyprland"` from
   `hyprflip`, so hyprflip keeps its own nightly-verified lock. Update the
   comment to point at the new file. `nixarchy.inputs.hyprland.url` (`/main`,
   the aquamarine fix) is **unchanged**, so p510 and nixarchy are untouched.
4. **`hosts/p620/nixos/nixarchy.nix`:** import the new file, and set
   `programs.hyprflip.package` and `hy3Package` to
   `inputs.hyprflip.packages.x86_64-linux.{hyprflip,hy3}`, which are the cached
   builds.
5. **`hosts/razer/nixos/nixarchy.nix`:** import the new file. The compositor
   changes only; razer still does not load hyprflip (see open question 1).

The portal packages are unchanged. razer forces `pkgs.xdg-desktop-portal-hyprland`
and p620 uses nixarchy's, and that is out of scope.

### Switching back (written in the new file's header)

1. Remove `../../common/nixos/hyprland-from-hyprflip.nix` from the imports of
   `hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`.
2. In `flake.nix`, restore `inputs.hyprland.follows = "nixarchy/hyprland";`
   on `hyprflip`, then run `nix flake lock`.
3. On p620, delete the `package` and `hy3Package` lines, or keep them only
   while both locks name the same commit.
4. Delete the file.

Change 1 (`omarchy-sole-hyprland.nix`) can stay, because it is correct either
way.

### Update routine during the trial

`nix flake update hyprflip` moves p620's and razer's compositor and plugins
together, to the last green night. `nix flake update nixarchy` no longer
changes their Hyprland. It still changes p510's.

## Alternatives rejected

- **`nixarchy.inputs.hyprland.follows = "hyprflip/hyprland"`:** it moves p510
  and every nixarchy host too. You chose p620 and razer only.
- **Overriding each host's `programs.hyprland.package` without fixing
  `omarchy-sole-hyprland.nix`:** `PATH` and the `cap_sys_nice` wrapper would
  keep nixarchy's Hyprland while the session runs hyprflip's, which is the
  #1566 mismatch.
- **Inline overrides in each host file instead of one shared file:** the
  switch-back steps and the trial note would be duplicated and drift apart.

## Risks

- **Wrong-priority override:** if nixarchy ever sets the package with
  `mkForce` itself, evaluation fails with a conflict. That is loud, not silent.
- **Hyprland a day or more behind the tip of `main`** on p620 and razer, and
  frozen while hyprflip nights are red. That is the intended trade.
- **razer's nvidia session on a different Hyprland build** from the one it has
  been running. The commit is the same today (`e368c13` in both locks), so the
  first switch is only a change of store path.
- **Login breakage** if a Hyprland consumer was missed. Mitigation: the
  verification below compares every Hyprland store path in the evaluated
  system. Rollback is the previous generation.

## Verification

1. **p510 unchanged:** `nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`
   is identical before and after.
2. **p620 and razer:** `config.programs.hyprland.package` equals
   `inputs.hyprflip.inputs.hyprland.packages.x86_64-linux.hyprland`. The
   `security.wrappers.Hyprland.source`, the greeter command and the session
   launcher all name that store path, and no other `hyprland-0.56` path appears
   in `environment.systemPackages`.
3. **p620 plugins:** `environment.etc."hyprflip/hyprflip.so".source` and
   `libhy3.so` are the paths that
   `nix path-info --store https://nixarchy.cachix.org` finds.
4. `nixos-rebuild build --flake .#p620` and `.#razer` succeed, and the build
   log shows `hyprflip`, `hy3` and Hyprland being copied, not built.
5. **Live switch (separate go-ahead for each host):** after logging in,
   `hyprctl version` shows `e368c13`, `hyprctl hyprflip status` responds on
   p620, and `hyprctl configerrors` is empty.

## Open questions

1. **Hyprflip on razer.** "Do this for p620 and razer" could also mean loading
   the plugins on razer. The default here is **no**: razer gets the verified
   Hyprland only, which is the trial you asked for. Enabling the plugins there
   would add the `hyprflip` module, `omarchy-hyprflip.nix` and the same two
   `package` lines. Say so if you want it.
