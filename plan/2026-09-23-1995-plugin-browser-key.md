---
status: draft
issue: 1995
spec: spec/2026-09-23-1995-plugin-browser-key.md
---

# Plan: Super+Alt+U opens the Plugin Browser again on p620 and razer

This plan is self-contained: it carries every approved spec decision.

## Decisions

- **A key-only module:** `hosts/common/nixos/omarchy-plugin-browser.nix`,
  in the shape of `omarchy-gog.nix`. It writes only
  `home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text`,
  containing:

  ```lua
  o.bind("SUPER + ALT + U", "Plugin browser", "nixarchy-plugin io.github.olafkfreund.nixarchy-plugin-browser")
  ```

- **No `menu.extraEntries` row.** Add Plugin stays nixarchy's own, with its
  `when` guard and aliases.
- **`bindings.lua` is not edited.** Its existing
  `pcall(require, "hypr.plugin-browser-binds")` (razer line 260, p620 line
  353) picks the file up.
- **Imported by `hosts/p620/nixos/nixarchy.nix` and
  `hosts/razer/nixos/nixarchy.nix`,** beside `omarchy-gog.nix`: the line
  #1991 removed. p510 is untouched.
- The module's header comment says why it exists (nixarchy seeds the key
  only for new homes; #1991; #1995), and why it holds no row.

## Steps

1. **Add `hosts/common/nixos/omarchy-plugin-browser.nix`** with the spec's
   content.
   → verify: `nix-instantiate --parse`; the pre-commit hooks (formatter,
   deadnix, statix) pass.
2. **Add the import to both hosts.**
   → verify: `git diff` shows exactly one added line per host file.
3. **Evaluate.**
   → verify: for p620 and razer,
   `home-manager.users.olafkfreund.home.file` has
   `.config/hypr/plugin-browser-binds.lua` with the `nixarchy-plugin` line;
   p510's does not.
4. **Build and diff.** `nix build` both toplevels.
   → verify: a closure diff by name against each running system shows only
   the new Home Manager file. The kernel and nvidia are unchanged.
5. **Open the PR ready,** linking the three artifacts, and get CI green.
   Merge by this repo's rules (squash), and check it with
   `git show origin/main:hosts/common/nixos/omarchy-plugin-browser.nix`.
6. **Deploy, announced on the bus:**
   - p620 with `sudo nixos-rebuild switch --flake .#p620`, from a clean
     worktree at main;
   - razer with `just deploy-via-p620 razer`, after the closure diff.

   → verify: `/run/current-system` is the new build, 0 failed units, and
   `~/.config/hypr/plugin-browser-binds.lua` exists on both.
7. **After the owner's re-login on razer:**
   - `hyprctl binds` shows Super+Alt+U → `nixarchy-plugin …`;
   - pressing it (ai-mirror, owner-granted) opens the panel.

## Tests

| Command | Expected |
|---------|----------|
| `nix eval .#nixosConfigurations.{p620,razer}.config.home-manager.users.olafkfreund.home.file` (the key) | the file with the `nixarchy-plugin` line |
| the same for p510 | absent |
| closure diff by name against each running system | only `hm_.confighyprpluginbrowserbinds.lua` |
| on both hosts: `test -f ~/.config/hypr/plugin-browser-binds.lua` | true |
| razer, after a re-login: `hyprctl binds` for modmask 72, key U | 1 bind, `nixarchy-plugin …` |

## Rollback

- Revert the PR and redeploy. The file disappears, and `pcall` keeps
  Hyprland loading without it; the key simply does nothing again.
