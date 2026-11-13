---
status: draft
issue: 2906
spec: spec/2026-11-13-2906-llm-index-razer.md
coders:
  1: codex   # small, scoping-sensitive Nix module change across four files
reviewers:
  - codex    # independent read of the diff against this plan
  - agy      # second read; checks the module scoping and the host values
---

# Plan: llm-index on razer as well as p620

Self-contained summary of the approved spec. Worktree
`~/.config/nixos-llmidx-razer`, branch `feat/llm-index-razer`. One editing
step; the lead builds, compares, commits, opens the PR and deploys.

## Steps

### 1. Per-host options, p620 value, razer import

Files: `hosts/common/nixos/llm-index.nix`, `hosts/p620/nixos/nixarchy.nix`,
`hosts/razer/nixos/nixarchy.nix`, `home/development/agent-rules.nix`.

- `hosts/common/nixos/llm-index.nix` (whole file, ~75 lines): change the
  outer function from `{ inputs, ... }:` to `{ config, lib, inputs, ... }:`
  and return `{ options.local.llmIndex = { … }; config.home-manager.users.olafkfreund = …; }`
  (a module with `options` cannot keep a top-level `home-manager`).
  - `options.local.llmIndex.sourcePath = lib.mkOption { type =
    lib.types.str; description = "Real path of the public source root (no
    symlink component)."; };` (no default).
  - `options.local.llmIndex.excludePaths = lib.mkOption { type =
    lib.types.listOf lib.types.str; default = [ ]; description = "Paths
    under a root to leave out of the index."; };`
  - Bind `hostCfg = config.local.llmIndex` in a `let` outside the inner
    Home Manager function (inside it, `config` is Home Manager's). The
    inner `{ config, lib, pkgs, ... }:` stays: its `lib` is needed for
    `lib.hm.dag`.
  - `roots.source.path = hostCfg.sourcePath;` (drop the hard-coded p620
    path and its comment) and add `exclude.paths = hostCfg.excludePaths;`.
    Nothing else in the file changes.
  - Header comment: p620 and razer; each host sets its own path.
- `hosts/p620/nixos/nixarchy.nix`: next to the existing import (~54), set
  `local.llmIndex.sourcePath = "/mnt/code/Source-home"; # real path;
  ~/Source is a symlink`.
- `hosts/razer/nixos/nixarchy.nix`: add `../../common/nixos/llm-index.nix`
  to `imports` (~24-40), and set `local.llmIndex.sourcePath =
  "/extdisk/Source";` (comment: real path; `~/Source` is a symlink and
  `/extdisk` is the second NVMe from fstab) and
  `local.llmIndex.excludePaths = [ "/extdisk/Source/password" ];`.
- `home/development/agent-rules.nix:8`: "p620 only" → "hosts that import
  hosts/common/nixos/llm-index.nix (p620, razer)".
- Check (implementer): `nix eval --json
  .#nixosConfigurations.razer.config.home-manager.users.olafkfreund.services.llm-index.exclude.paths`
  gives `["/extdisk/Source/password"]`; the same for p620 gives `[]`;
  `nix eval --raw .#nixosConfigurations.razer.config.home-manager.users.olafkfreund.services.llm-index.roots.source.path`
  gives `/extdisk/Source` (and p620's gives `/mnt/code/Source-home`);
  `nix flake check --no-build` evaluates, and `deadnix --fail` and
  `nixpkgs-fmt --check` pass on the four files. (`just validate` runs the
  full flake check with VM tests; the lead runs it.)
- Traps: never work in `~/.config/nixos` itself; no stage, commit,
  deploy or switch; keep the files nixpkgs-fmt clean (the lead's commit
  runs the pre-commit hooks); the `local.llmIndex` settings go at the top
  level of each host's `nixarchy.nix`, not inside `imports`.

## Tests (lead)

- `just validate`, and `nix build` of p620 and razer toplevels.
- p620 unchanged: under
  `.#nixosConfigurations.p620.config.home-manager.users.olafkfreund`,
  these are equal on this branch and on `origin/main`:
  `xdg.configFile."llm-index/config.toml".source` (config),
  `xdg.configFile."systemd/user/llm-index.service".source` (unit) and
  `home.activation.llmIndexMcp.data` (activation text).
- CI on the PR (p620, razer, p510).
- Deploy (after the bus announcement, from `main`): razer with the
  `deploy-via-p620` recipe, then p620.
- razer live checks:
  - `systemctl --user is-active llm-index`; self-test journal lines
    (sockets and signal denied, `dumpable=false`/`true`);
  - `llm-index status`: `source` and `docs` reach `ok` **and** show
    `files` > 0 (a root is `ok` once its scan ends, before extraction);
    the client and isolation checks below wait for that;
  - Claude Code, Codex and agy on razer each return a hit from
    `/extdisk/Source`;
  - isolation: pick a term the private server finds in `~/Documents`
    (`llm-index mcp --tier private` search); the public server returns no
    hit for it, and a public `search` with that `query` and `folder`
    `/home/olafkfreund/Documents` succeeds with no hits;
  - `~/.config/llm-index/config.toml` on razer lists the exclusion.
- p620 live check: service active, a search from the three clients works.

## Rollback

Revert the merge on `main` and redeploy razer and p620; razer's
`~/.local/state/llm-index` can then be removed by hand.
