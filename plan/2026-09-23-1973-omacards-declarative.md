---
status: draft
issue: 1973
spec: spec/2026-09-23-1973-omacards-declarative.md
---

# Plan: declare OmaCards on p620, with its Hyprflip helper and shortcuts

## Approved decisions (from the spec)

- **One owner:** everything goes into the existing
  `hosts/common/nixos/omarchy-hyprflip.nix`, under its
  `attrByPath [ "programs" "hyprflip" ]` guard. The module gains `inputs`. No
  new import line.
- **Plugin:** a new flake input `omacards = { url = "github:nocstah/omacards"; flake = false; };`,
  locked to the reviewed `97a331e`. Declared with
  `home-manager.users.olafkfreund.programs.nixarchy.plugins."io.github.nocstah.omacards".src = inputs.omacards;`.
  A comment notes that `omarchy plugin update` skips it (no `.git`) and that
  updates are `nix flake update omacards`.
- **Helper:** `home.file.".local/lib/hyprflip/{control,workflow,shortcuts,setup}.py".source`
  = `${inputs.hyprflip}/scripts/<f>`. `setup.py` is new, for C and L.
- **Protocol assertion,** evaluated purely: `PROTOCOL = N` in the helper's
  `control.py` must equal `data.protocol !== N` in OmaCards' `Service.qml`. A
  pattern that no longer matches fails with a "check needs updating" message.
- **Shortcut Lua:**
  - `hyprflip-shortcuts.lua` from the input's `examples/shortcuts.lua`, verbatim;
  - `hyprflip-preferences.lua` from the input's `examples/preferences.lua`,
    verbatim;
  - `examples/containers-setup.lua` appended to the generated `hyprflip.lua`
    after the hy3 block, only when `containers.enable` is set. That gives O
    (combined, replacing #1967's), C, L and Space.
  - User state stays in `~/.local/state/hyprflip/`, untouched.
- **Cutover:** check `~/.local/state/hyprflip/`, then `mv` the hand clone to
  `~/.config/omarchy/plugins/.io.github.nocstah.omacards.bak-1973` right before
  the switch. Two shell reloads, ~40 s each.
- **When it takes effect:** the plugin and helper at the switch; the shortcut
  Lua at the next re-login. No `hyprctl reload`.
- **Only p620.** razer and p510 must still evaluate.

## Preconditions

- **P1 (changed since the spec):** #1969, #1970 and #1972 are **merged**. This
  branch is still stacked on the pre-merge #1972 branch, so it is rebased onto
  `origin/main` first (step 1). The switch then builds from this branch alone,
  and the `apps.nix` cherry-pick used for #1967 is no longer needed.
- **P2:** before the switch, p620's running system must equal a build of
  `origin/main` at the commit this branch is based on (the same closure check as
  #1967's P3). Otherwise the switch would roll back whatever else p620 runs.
- **P3:** OmaCards' upstream HEAD is `97a331e` (checked 2026-09-23). If the lock
  resolves anywhere else, review those commits first, or pin
  `github:nocstah/omacards/97a331e…` explicitly.

## Steps

1. **Rebase onto `main`:**
   `git rebase --onto origin/main <#1967 feature commit 36c220bd2> feat/1973-omacards-declarative`
   carries over only this issue's commits, whether or not #1972 was squashed.
   Verify: `git log origin/main..` shows only #1973 commits, and
   `omarchy-hyprflip.nix` on `main` has the #1967 content.

2. **`flake.nix` and `flake.lock`:** add the `omacards` input (with a comment in
   the style of the `hyprflip` input's), then `nix flake lock --update-input omacards`.
   Verify: `jq '.nodes.omacards.locked.rev' flake.lock` = `97a331e63ebe…`.

3. **`hosts/common/nixos/omarchy-hyprflip.nix`:** extend the module.
   - Add `inputs` to the arguments.
   - Add the plugin declaration, the four `home.file` helper links, the two Lua
     module files (`.source` from the input's `examples/`), the setup block
     appended to the `hyprflip.lua` text inside the existing
     `optionalString cfg.containers.enable` (read with `builtins.readFile` from
     the input, so it stays verbatim), and the protocol assertion.
   - Update the header comment to cover OmaCards, the `plugin update` note and
     the cutover trap.
   - Verify: `nix-instantiate --parse`, then `nixpkgs-fmt`. The formatter's
     rewrite must not change generated text, which is checked in step 5.

4. **Build:** the p620 toplevel builds, and razer and p510 `drvPath` evaluate.

5. **Inspect what the build produces** (from `home-manager-files`):
   - `hyprflip.lua` starts with header + hand file (sha `8fd141c3…`), then the
     hy3 block, then `containers-setup.lua` byte for byte;
   - `hyprflip-shortcuts.lua` and `hyprflip-preferences.lua` are byte-equal to
     the input's `examples/`;
   - the four helper links point into `${inputs.hyprflip}/scripts/`;
   - the nixarchy plugin link for `io.github.nocstah.omacards` resolves to
     `inputs.omacards`.

6. **Negative test of the protocol assertion** (not committed): swap the
   OmaCards side for a string with `data.protocol !== 2` and evaluate. It must
   fail with the mismatch message. Then a string with no match at all must fail
   with "check needs updating". Revert, and confirm with `git diff`.

7. **Nested-session proof**, as in #1967 step 5 (`/tmp/hfn`, `/tmp/hfs`, the
   built libraries, and `Hyprland` `23118f9f`), but with the **generated**
   `hyprflip.lua`, `hyprflip-shortcuts.lua` and `hyprflip-preferences.lua`
   loaded into the nested session's config:
   - `configerrors` empty;
   - `hyprflip` and `hy3` loaded;
   - binds for O ("unfold, fold or create a card"), C, L and Space registered
     with upstream's descriptions, and M/S/F/U/Escape and H/V/E still present.

   Tear down with SIGINT **to the Python harness PID** (not the shell wrapper),
   confirm no nested Hyprland is left, and remove `/tmp/hfn` and `/tmp/hfs`.
   Any failure stops the plan.

8. **Commit** `feat(hyprflip): declare OmaCards, its helper and shortcuts (#1973)`,
   then push.

9. **Cutover and switch on p620:**
   - Read the bus, then post (~10 min, two bar freezes, shortcuts at
     re-login).
   - Check P2 against the running system.
   - Record `ls -la ~/.local/state/hyprflip/` (saved cards, if any).
   - `mv` the hand clone to `.io.github.nocstah.omacards.bak-1973`. Wait for the
     shell to answer IPC.
   - Build from the committed ref, then `nix-env -p … --set` and
     `switch-to-configuration switch`.
   - Afterwards:
     - `~/.config/omarchy/plugins/io.github.nocstah.omacards` is a **symlink**
       into the store;
     - the helper files are Home Manager links, and the old copies are in
       `~/.hm-backups/`;
     - `listPlugins` shows OmaCards enabled;
     - the helper `snapshot` gives protocol 1 and `containers: true`;
     - `~/.local/state/hyprflip/` is unchanged;
     - no failed units.

10. **Owner re-logs in**, then run the live checks:
    - binds: O has the combined description; C, L and Space are registered;
      M/S/F/U/Escape and H/V/E are unchanged;
    - `configerrors` is empty;
    - plugins are `hyprflip` and `hy3`;
    - the owner confirms the bar icon opens the panel and **C opens the editor**.

    Post the results on the bus.

11. **Open the PR** linking the intent, spec and plan and #1973, with the step 5,
    6, 7, 9 and 10 evidence. After the merge, remove the leftover worktrees and
    local branches from #1967 and #1973 (`deploy/1967-p620`, `nixos-hyprflip`,
    `nixos-apps`, `nixos-deploy`, `nixos-1967`, `nixos-1973`). Delete the
    `.bak-1973` clone only when the owner agrees.

## Tests

| Check | Expected |
| --- | --- |
| p620 toplevel build; razer and p510 eval | Build succeeds; both evaluate |
| `flake.lock` `omacards` rev | `97a331e63ebe…` |
| Generated `hyprflip.lua` | #1967 content byte for byte (core sha `8fd141c3…`) + hy3 + `containers-setup.lua` verbatim |
| `hyprflip-shortcuts.lua` and `hyprflip-preferences.lua` | Byte-equal to the input's `examples/` |
| Protocol assertion with a fake `2` / a missing pattern | Evaluation fails with the right message |
| Nested session | `configerrors` empty; O/C/L/Space plus the existing binds registered |
| After the switch | Plugin path is a store symlink; helper `snapshot` gives protocol 1 and containers true; state dir unchanged |
| After re-login | Binds as above; C opens the editor |

## Rollback

- **Plugin:** `rm` the plugin symlink, `mv` the `.bak-1973` folder back, and
  `sudo nixos-rebuild switch --rollback` (after a bus notice). The shell picks up
  the clone on its reload.
- **Helper:** the rollback restores the previous Home Manager links. The hand
  copies are in `~/.hm-backups/` if needed.
- **Shortcuts:** they apply only at login. If the Omarchy session breaks, log in
  to GNOME and roll back.
- **After merge:** `git revert` the feature commit.
