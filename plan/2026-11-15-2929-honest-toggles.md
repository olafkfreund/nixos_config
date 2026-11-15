---
status: draft
issue: 2929
spec: spec/2026-11-15-2929-honest-toggles.md
coders:
  1: codex  # small but tricky: wrapping three large HM files under config = mkIf without changing their contents
  2: codex  # terminals bridge, MIME guard and the per-host preservation values
  3: agy    # mechanical deletions across modules and three hosts
  4: agy    # mechanical type change in eight files
  5: agy    # split one mkIf into two in claude-hooks.nix, and the one-line screens.nix fix
reviewers:
  - codex   # read-only diff review against this plan
  - agy     # read-only diff review against this plan
---

# Plan: make feature toggles control what they claim

Approved decisions (from the spec): gate the three HM development files and the three terminals on their existing
options; preserve every host's current packages by setting host values to today's reality (p510 needs `mkForce`
because it imports two profiles that disagree); set the terminal MIME default only when a terminal is enabled;
install each Claude notification script under its own flag; delete `aiDefaults.profile` and `syncthing.masterHost`;
`listOf package` for development `packages`; call `variables.nix` in `screens.nix`. Only user is `olafkfreund`.
No deploy. Step 0 (`scripts/config-snapshot.sh`) was written by Claude before the steps and is part of this PR.

## Steps

0. `scripts/config-snapshot.sh` (new): `snap <dir>` evaluates each host's toplevel with
   `system.configurationRevision` pinned, builds it, and records names; `diff <a> <b>` prints `IDENTICAL` or the
   differences. Baseline taken from a detached `main` worktree at `cec62a474`.
1. `home/development/{languages,workflow,productivity}.nix`: add `config` to the function args if missing; wrap all
   existing top-level attributes (after `let ... in {`) in
   `config = lib.mkIf (config.features.development.enable && config.features.development.<x>) { ... };`.
   `Users/olafkfreund/p510_home.nix`: `productivity = lib.mkForce false` →
   `productivity = lib.mkForce true; # was never honoured; keeps today's apps (#2929)`.
   → verify: p510 HM `home.packages` still contains obsidian, slack, discord, telegram-desktop.
   Anchors: args at :3-6 of each file; bodies `languages.nix:210-357`, `workflow.nix:155-411`,
   `productivity.nix:343-681`; `p510_home.nix:69`.
   Expected side effect: p510 HM gains `claude-desktop` (`home/development/claude-desktop/default.nix:15` already reads
   this flag); it is already in p510's system packages. Accepted.
   Traps: do not change the internal `let cfg`; the formatter is `nixpkgs-fmt` (`nix fmt`), not `nixfmt`.
2. `home/desktop/terminals/default.nix`: take `config` in the args; inside `cfg.terminals` (:13-15) set
   `foot = config.foot.enable; kitty = config.kitty.enable; alacritty = config.alacritty.enable;`.
   Wrap `xdg.mimeApps` (:338-358) in `mkIf (cfg.terminals.kitty || cfg.terminals.foot || cfg.terminals.alacritty)`
   and drop the final `else "foot.desktop"` fallbacks' reachability (keep the chain, it is now only reached with one on).
   `Users/olafkfreund/profile.nix:73-74`: `kitty = true;` and rewrite the comment on :73 (every host already had kitty;
   now honoured, #2929); leave `ghostty` on :75 alone. `Users/olafkfreund/p620_home.nix:12` comment no longer says
   workstation-only.
   `Users/olafkfreund/p510_home.nix:97`: next to `ghostty.enable = lib.mkForce true;` add
   `foot.enable = lib.mkForce true; kitty.enable = lib.mkForce true; alacritty.enable = lib.mkForce true;` with a
   one-line comment. → verify: HM `programs.{foot,kitty,alacritty}.enable` true on all three hosts.
   Traps: `config` must be a function argument before `cfg` can read it.
3. `modules/common/ai-defaults.nix:4,8-12`: delete the `profile` option and drop `mkOption` and `types` from the
   `inherit` on :4 (deadnix). `hosts/{p620,razer,p510}/configuration.nix`:
   delete the `profile = ...;` line inside `aiDefaults = { ... };` (delete the block if nothing else is left) and fix its comment (razer's says it disables Ollama; it never did).
   `modules/services/syncthing.nix:62`: delete the `features.syncthing.masterHost` option; delete `masterHost = "p620";` in the three
   hosts. Keep any comment that explains other settings. → verify: `just check-syntax`; grep shows no
   `masterHost` and no `aiDefaults` profile assignment.
4. `modules/development/{nodejs,python,go,java,lua,cargo,github,shell}.nix:14` (python's is
   `modules.development.python.packages`): the `packages` option's
   `listOf str` → `listOf package` (only that option). → verify: grep.
5. `modules/development/claude-hooks.nix:66-69`: replace the single `mkIf (a || b) [ both ]` with
   `optional cfg.enablePermissionNotifications (writeScriptBin "claude-notify-permissions" ...) ++ optional cfg.enableReadyNotifications (writeScriptBin "claude-notify-ready" ...)`.
   `hosts/{p620,razer,p510}/nixos/screens.nix:3`: `import ../variables.nix;` → `import ../variables.nix { };`.
   (razer's uses `inherit (vars) hostName;`; same fix.) `hosts/*/README.md` examples that show the uncalled import
   get `{ }` too.
   → verify: `nix eval .#nixosConfigurations.p620.config.home-manager.extraSpecialArgs.vars.hostName` = "p620".
6. Docs (Claude): `docs/` pages that describe these toggles (grep `productivity`, `features.terminals`,
   `masterHost`, `aiDefaults`, `claude-notify`) say the toggles now work; `scripts/README.md` lists
   `config-snapshot.sh`.

## Tests

- `scripts/config-snapshot.sh snap <new>` then `diff <base> <new>`: p620, razer and p510 `IDENTICAL` (all three
  toplevels built on p620) — except p510's expected `hmpkgs: > claude-desktop`.
- Negative checks, each through `extendModules` on p620: productivity off → no `obsidian` in HM packages; kitty off →
  `programs.kitty.enable` false; `enablePermissionNotifications = false` → no `claude-notify-permissions`, still
  `claude-notify-ready`.
- `just check-syntax`; `nix build .#checks.x86_64-linux.deadnix-check` (or `just validate`); CI green; `@codex review` clean.

## Rollback

Revert the squash commit; no state, no deploy.
