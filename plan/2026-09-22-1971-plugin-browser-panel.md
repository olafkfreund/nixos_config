---
status: approved
issue: 1971
spec: spec/2026-09-22-1971-plugin-browser-panel.md
---

# Plan: Plugin Browser as Add Plugin, and on Super+Alt+U, on p620

This plan is self-contained; it carries every approved decision.

## Approved decisions

- **p620 only.** razer does not import the module.
- **The menu row comes from `extraEntries`,** not a hand edit of the
  extensions file.
- **A new plain module, `hosts/common/nixos/omarchy-plugin-browser.nix`,**
  shaped like `omarchy-gog.nix`. It has no `mkEnableOption`; importing it
  enables it. It holds two things:
  - `programs.nixarchy.menu.extraEntries."setup.plugin.add"
    = { icon = "󰖟"; label = "Add Plugin";
    action = "omarchy-shell shell toggle io.github.olafkfreund.nixarchy-plugin-browser '{}'"; }`.
    All three keys are restated, because an override blanks any key it
    leaves out.
  - `home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text`
    with one `o.bind("SUPER + ALT + U", "Plugin browser", "<same action>")`
    and a "managed by" header.
- **One import line** in `hosts/p620/nixos/nixarchy.nix`, after
  `../../common/nixos/omarchy-stylix-theme.nix`. If #1967 merges first, keep
  its two lines and this one.
- **Outside the repo:** one `pcall(require, "hypr.plugin-browser-binds")` in
  `~/.config/hypr/bindings.lua`, added only with the user's consent.
- **No build and no deploy by the agent.** The user deploys, announced on the
  bus first.

## Steps

1. Add `hosts/common/nixos/omarchy-plugin-browser.nix` exactly as the spec
   shows, with its header comment.
   → verify: the pre-commit hooks pass (nix formatting included).
2. Add the import line to `hosts/p620/nixos/nixarchy.nix`.
   → verify: `git diff` is exactly one added line.
3. Run the evaluation checks from the Tests table, from the worktree.
   → verify: every result matches the table.
4. Commit steps 1–2 as `feat(omarchy): Plugin Browser as Add Plugin and on Super+Alt+U (#1971)`.
   Push the branch and open a PR that links the intent, spec and plan and
   closes #1971, and link nixarchy-plugin-browser#5.
   → verify: the PR exists and its diff is two files.
5. Show the user the `bindings.lua` line, and add it only after a yes.
   → verify: `grep -c 'hypr.plugin-browser-binds' ~/.config/hypr/bindings.lua`
   is 1.
6. The user merges by this repo's rules, announces the deploy on the bus and
   deploys p620, then installs and enables the plugin. Then the desktop checks
   in Tests.

## Tests

| Check | Expected |
|-------|----------|
| `nix eval .#nixosConfigurations.p620.config.programs.nixarchy.menu.extraEntries --json \| jq -c '."setup.plugin.add"'` | `{"action":"omarchy-shell shell toggle io.github.olafkfreund.nixarchy-plugin-browser '{}'","icon":"󰖟","label":"Add Plugin"}` |
| `nix eval --raw '.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text'` | contains `o.bind("SUPER + ALT + U", "Plugin browser", …)` |
| `nix eval .#nixosConfigurations.razer.config.programs.nixarchy.menu.extraEntries --json \| jq 'has("setup.plugin.add")'` | `true` (razer added, see Deviations) |
| pre-commit hooks | pass |
| **After deploy (user):** `ls -l ~/.config/hypr/plugin-browser-binds.lua` | a Home Manager symlink |
| Super+Alt+U | toggles the Plugin Browser panel |
| Setup → Plugins → Add Plugin | opens the panel |
| Enable / Disable / Clone / Remove Plugin | unchanged |

## Deviations recorded during implementation

- **razer as well as p620 (2026-09-23, user request).** This reverses the
  approved "p620 only" decision. razer imports the same module from
  `hosts/razer/nixos/nixarchy.nix`, and the razer check in Tests is now
  expected `true`. It goes to razer through the p620 build path AGENTS.md
  names for that host. razer's own `bindings.lua` needs the same `pcall` line.
- Steps 1, 2 and 4 were committed by another session (`a9d247642`, PR #1974).
  Step 3's evaluation checks were run and posted on the PR.

## Rollback

- Remove the import line from `hosts/p620/nixos/nixarchy.nix` and deploy. The
  row returns to `omarchy-plugin-add` and the binds file disappears.
- The `pcall` line in `bindings.lua` then does nothing, by design.
- Or roll back to the previous p620 generation.
