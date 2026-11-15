---
status: draft
issue: 2929
spec: spec/2026-11-15-2929-honest-toggles.md
coders:
  1: codex  # small but tricky: wrapping three large HM files under config = mkIf without changing their contents
  2: codex  # terminals bridge plus the per-host preservation values
  3: agy    # mechanical deletions across modules and three hosts
  4: agy    # mechanical type change in eight files
  5: agy    # one-line change in three files
reviewers:
  - codex   # read-only diff review against this plan
  - agy     # read-only diff review against this plan
---

# Plan: make feature toggles control what they claim

Approved decisions (from the spec): gate the three HM development files and the three terminals on their existing
options; preserve every host's current packages by setting host values to today's reality; delete `aiDefaults.profile`
and `syncthing.masterHost`; `listOf package` for development `packages`; call `variables.nix` in `screens.nix`.
Only user is `olafkfreund`. No deploy.

## Steps

1. `home/development/{languages,workflow,productivity}.nix`: add `config` to the function args if missing; wrap all
   existing top-level attributes (after `let ... in {`) in
   `config = lib.mkIf (config.features.development.enable && config.features.development.<x>) { ... };`.
   `Users/olafkfreund/p510_home.nix`: `productivity = lib.mkForce false` → `productivity = true;  # was never honoured; keeps today's apps (#2929)`.
   → verify: `nix eval` of p510 HM `home.packages` still contains obsidian/slack/discord/telegram-desktop.
   Traps: do not change the internal `let cfg`; keep indentation nixfmt-clean (`nix fmt` / pre-commit).
2. `home/desktop/terminals/default.nix`: take `config` in args; inside `cfg.terminals` set
   `foot = config.foot.enable; kitty = config.kitty.enable; alacritty = config.alacritty.enable;`.
   `Users/olafkfreund/profile.nix:74-75`: `kitty = true;` (comment: all hosts already had it; now honoured, #2929).
   `Users/olafkfreund/p510_home.nix`: next to `ghostty.enable = lib.mkForce true;` add
   `foot.enable = lib.mkForce true; kitty.enable = lib.mkForce true; alacritty.enable = lib.mkForce true;` with a one-line comment.
   → verify: HM `programs.{foot,kitty,alacritty}.enable` true on all three hosts.
   Traps: `cfg` is defined in `let` before `config` is in scope only if `config` is a function arg — add it to the args.
3. `modules/common/ai-defaults.nix`: delete `profile` option. `hosts/{p620,razer,p510}/configuration.nix`: delete the
   `profile = ...;` line inside `aiDefaults = { ... };` (keep the block if it has other attrs, else delete it).
   `modules/services/syncthing.nix:62`: delete `masterHost` option; delete `masterHost = "p620";` in the three hosts.
   → verify: `just check-syntax`; `grep -rn 'masterHost\|aiDefaults.profile\|profile = "' hosts modules` shows none for these.
4. `modules/development/{nodejs,python,go,java,lua,cargo,github,shell}.nix`: `type = with types; listOf str;` →
   `type = with types; listOf package;` for the `packages` option only. → verify: grep.
5. `hosts/{p620,razer,p510}/nixos/screens.nix:3`: `import ../variables.nix;` → `import ../variables.nix { };`.
   → verify: `nix eval .#nixosConfigurations.p620.config.home-manager.extraSpecialArgs.vars.hostName` = "p620".
6. Docs: `docs/` pages that describe these toggles (grep `productivity`, `features.terminals`, `masterHost`,
   `aiDefaults`) updated to say the toggles now work and list the preserved host values.

## Tests

`snap.sh` after all steps vs the `main` baseline: every check `same`/`identical` on all three hosts, `diff-closures`
empty except the toplevel; all three toplevels build on p620. `just check-syntax`. CI green. `@codex review` clean.

## Rollback

Revert the squash commit; no state, no deploy.
