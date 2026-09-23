---
status: approved
issue: 1983
intent: intent/2026-09-23-1983-nixd-lsp-agents.md
---

# Spec: nixd + nixfmt as the Nix language server for Claude Code and Codex

## Research findings that shape the design

Checked against the nixd 2.9.2 source and the current installs:

1. **nixd ignores `~/.config/nixd/nixd.json`.** nixd 2.x gets its
   configuration only through LSP `workspace/configuration` or from
   command-line flags. `home/development/nixd.nix` has written that file on
   every host since v1, and nothing reads it. The file is also wrong in two
   ways: it names `alejandra` as the formatter, and `hostName` is hard-coded
   to `p620`.
2. **Command-line flags work with any client.** Three flags matter:
   - `--nixos-options-expr` starts the NixOS option worker at init.
   - `--nixpkgs-expr` starts the nixpkgs worker at init.
   - `--config=<json>` sets the initial config. This covers `formatting`
     and `diagnostic`, but not `options`: `--config` assigns `Config` without
     calling `updateConfig()`, so no extra option worker ever starts
     (`nixd/lib/Controller/LifeTime.cpp:192`).
3. **Home Manager option completion needs `workspace/configuration`.**
   Neither client is known to answer that request. Claude Code sends plugin
   `settings` through `didChangeConfiguration`, and nixd reacts by sending a
   `workspace/configuration` request back, so it depends on Claude answering
   it. `mcp-language-server` is unknown.
4. **No agent ever asks the server to format.** Claude Code's `LSP` tool
   has no formatting operation, and `mcp-language-server` offers none
   either. Formatting therefore comes from PostToolUse hooks. Claude Code
   already has one, `formatScript` in
   `modules/programs/claude-code-managed.nix`, which hard-codes
   `nixpkgs-fmt`. Codex has none.
5. **Codex gets MCP servers through `codex mcp add`,** which writes
   `~/.codex/config.toml`. Codex hooks live in `~/.codex/hooks.json`, which
   herdr also writes to. A PostToolUse hook on `apply_patch` receives the
   patch text, not a list of paths. Codex asks for trust on a new hook once
   (`[hooks.state] trusted_hash`). `~/.codex` is not synced.
6. **`~/.claude/plugins/**` is synced.** The local marketplace file
   `plugins/custom-marketplace/.claude-plugin/marketplace.json` is a
   home-manager `/nix/store` symlink, so Syncthing sends one host's store
   path to the other hosts. This is the same failure as the 2026-09-13
   skills incident. Claude Code reads a directory marketplace live, so a
   changed `lspServers` block takes effect on its next start with no
   reinstall.
7. **Resolving the formatter per repo is cheap.** `nix eval .#formatter`
   in this repo takes 0.45 s warm, and it gives `nixpkgs-fmt-1.3.0`.

## Design

### 1. `pkgs/nix-format` — one formatter both agents use

A new `writeShellApplication` exposed as `pkgs.customPkgs.nix-format`.

- `nix-format FILE…` walks up from each file to the nearest `flake.nix`. If
  that flake has a `formatter.<system>` output, it runs `nix fmt -- FILE`.
  Otherwise it runs `nixfmt FILE`. It exits 0 in every case, so a hook can
  never fail the tool. Each call has a 30 s `timeout`.
- `nix-format --stdin` does the same for nixd's `formatting.command`: it
  resolves the formatter from `$PWD`, writes stdin to a temporary `.nix`
  file, formats it and prints the result.

This implements decision 1: `nixpkgs-fmt` here, `nixfmt` wherever a repo
sets no formatter, with no hard-coded formatter name.

### 2. `home/development/nixd.nix` — rewritten as the single nixd definition

- Remove the dead `xdg.configFile."nixd/nixd.json"` and the options that
  only fed it: `offlineMode`, `formatterCommand` and `diagnostics*`.
- `hostName` defaults to `osConfig.networking.hostName` (decision 3), and
  `flakeDir` stays.
- Install a `nixd-agent` wrapper (`writeShellScriptBin`) that runs:

  ```text
  nixd --nixos-options-expr='(builtins.getFlake "git+file://<flakeDir>").nixosConfigurations.<host>.options'
       --nixpkgs-expr='import (builtins.getFlake "git+file://<flakeDir>").inputs.nixpkgs { }'
       --config='{"formatting":{"command":["nix-format","--stdin"]}}'
       "$@"
  ```

  Both agents launch it by name. Every per-host value lives in the wrapper,
  on this host's PATH, never in a synced file.
- Update `Users/olafkfreund/private.nix` to drop the removed options.

### 3. Claude Code — `home/development/claude-code-lsp.nix`

- In the plugin entry `lspServers`, replace `nil` with `nixd` and set its
  command to `nixd-agent` (decision 2). Bump the version to `1.1.0`.
- Rewrite the README for nixd. The false "formatting with nixpkgs-fmt"
  claim goes.
- Add `/plugins/custom-marketplace` to the `.claude` ignore list in
  `home/syncthing-stignore.nix`, so the store symlink stops syncing
  (finding 6).
- `modules/programs/claude-code-managed.nix`: `formatScript` calls
  `nix-format` instead of `nixpkgs-fmt`. The `formatOnEdit` description is
  updated to match.

### 4. Codex — `home/development/codex-cli.nix`

- A home-manager activation entry, run after `writeBoundary`. If `codex`
  exists and `codex mcp get nixd` fails, it runs
  `codex mcp add nixd -- mcp-language-server --workspace . --lsp nixd-agent`.
  The command uses stable names only, so it runs once per host and needs no
  rewrite on each rebuild. It is guarded with if/else, never `exit`, as the
  existing activation note requires.
- A Codex PostToolUse hook, `codex-nix-format`, with matcher
  `apply_patch|Edit|Write`. It reads `tool_input.command`, takes the paths
  from `*** Add File:`, `*** Update File:` and `*** Move to:`, resolves them
  against `.cwd`, and passes any `.nix` files to `nix-format`. It is merged
  into `~/.codex/hooks.json` with `jq`, adding the entry only if it is
  missing, so herdr's `SessionStart` entry survives. Codex asks once per
  host to trust the new hook.
- Add `mcp-language-server` to `home.packages` (decision 4: every host that
  imports `home/development`, which is p620, razer and p510).

### 5. Documentation

A new page, `docs/tooling/nix-lsp-agents.md`, linked from both
`mkdocs.yml` and `mkdocs-full.yml`. It covers:

- which agent gets what: the Claude `LSP` tool operations, and the Codex
  MCP tools;
- how `nixd-agent` works, and why its settings are flags rather than a JSON
  file;
- why formatting runs through hooks, and how the formatter is chosen per
  repo;
- per-host options, and the Home Manager limitation;
- how to verify the setup, and how to troubleshoot it (`--log` of
  `mcp-language-server`, `claude --debug`).

## Alternatives rejected

- **Configuring nixd through `workspace/configuration` only**, with Claude
  plugin `settings`: whether that works depends on each client answering
  the request (finding 3). It is unverified for both clients and would give
  Codex nothing. Flags work with every client.
- **Putting host args directly in `marketplace.json`:** that file syncs, so
  the hosts would overwrite each other's `hostName`, exactly as the skills
  did on 2026-09-13.
- **Generating `~/.codex/config.toml` from Nix:** Codex rewrites that file
  itself (trust levels, hook hashes, TUI state), and the repo already
  decided not to manage it (`codex-cli/module.nix`).
- **Running `nixfmt` unconditionally:** rejected by decision 1.
- **Keeping `nil`:** rejected by decision 2.

## Risks

- **Option-worker memory and time.** Evaluating
  `nixosConfigurations.<host>.options` takes tens of seconds and a few
  hundred MB per nixd process, and each agent session starts its own
  process. razer is the most constrained host. Mitigation: the evaluation
  runs in the background and nixd still works without it; we measure it on
  razer during verification.
- **`getFlake "git+file://…"` sees tracked files only.** A new, untracked
  module is invisible to option completion until it is `git add`-ed. This
  goes in the docs.
- **`mcp-language-server --workspace .`:** if Codex does not start MCP
  servers in the session's working directory, the workspace is wrong. The
  fallback is `flakeDir`, found during verification.
- **Editing `hooks.json`:** a bad `jq` merge could drop herdr's entry. The
  merge is additive and checked by eye on the first host.
- **Home Manager option completion is out of scope,** unless verification
  shows Claude answers `workspace/configuration`. In that case it can be
  added later through plugin `settings`.
- **p510:** the build is tested with `just test-host p510`, but it is not
  deployed without asking.

## Verification

1. `just check-syntax`, then `just test-host p620`, `just test-host razer`
   and `just test-host p510`.
2. `nix-format` on a temporary file in this repo gives `nixpkgs-fmt` output.
   In a scratch directory with no flake it gives `nixfmt` output. It exits 0
   on a file with a syntax error.
3. After the p620 switch:
   - Start `nixd-agent` and send a hand-written LSP `initialize`, then check
     the log for "evaluated nixos options" with no errors.
   - In Claude Code, `LSP hover` on `features.sunshine.enable` in a host
     file returns the option description, which is proof that the p620
     options loaded.
   - Edit a `.nix` file through Claude and see that it stays
     `nixpkgs-fmt`-clean (`nixpkgs-fmt --check`).
4. In Codex on p620:
   - `codex mcp list` shows `nixd`.
   - Asking for `diagnostics` on a file with a deliberate error returns it.
   - An `apply_patch` edit to a `.nix` file comes back formatted.
   - `~/.codex/hooks.json` still has herdr's `SessionStart`.
5. `~/.claude/.stignore` contains `/plugins/custom-marketplace`, and
   Syncthing's REST API shows the rule loaded (per memory: check the
   loaded rules, not the file).
6. The docs build (`mkdocs build --strict` or the repo's docs gate), and
   markdownlint passes on the new page.
