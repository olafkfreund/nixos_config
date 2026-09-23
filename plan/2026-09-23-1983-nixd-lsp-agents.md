---
status: draft
issue: 1983
spec: spec/2026-09-23-1983-nixd-lsp-agents.md
---

# Plan: nixd + nixfmt as the Nix language server for Claude Code and Codex

## Approved decisions, carried over from the spec

- **Formatter follows the repo.** Nix edits made by either agent are
  formatted with the repo's formatter, meaning its flake `formatter.<system>`
  output (`nixpkgs-fmt` here), or with `nixfmt` when the repo has none. No
  bulk reformat. One script, `nix-format`, makes that choice for the
  Claude hook, the Codex hook and nixd's `formatting.command`.
- **nixd replaces nil** in Claude Code.
- **Each host evaluates its own options**, from
  `nixosConfigurations.<osConfig.networking.hostName>`.
- **Codex gets nixd on every host** that imports `home/development`: p620,
  razer and p510.
- **nixd is configured by command-line flags**, not by a JSON file or
  `workspace/configuration`. The flags are `--nixos-options-expr`,
  `--nixpkgs-expr` and `--config='{"formatting":…}'`. They live in a
  per-host `nixd-agent` wrapper on PATH, and both agents launch it by name.
  Nothing per-host goes into a synced file.
- **Formatting comes from PostToolUse hooks,** because no agent sends an
  LSP formatting request.
- **Codex bridges to nixd through `mcp-language-server`,** registered once
  per host with `codex mcp add`. `~/.codex/config.toml` stays unmanaged.
  The Codex hook is merged into `~/.codex/hooks.json` with `jq`, adding
  only what is missing.
- **Home Manager option completion is out of scope.**
- **`/plugins/custom-marketplace` stops syncing** in `~/.claude`.
- **Docs** go in `docs/tooling/nix-lsp-agents.md`, linked from both mkdocs
  nav files.
- **p510:** a test build only. It is deployed only when you ask.

## Steps

1. **`pkgs/nix-format/default.nix` (new) and `pkgs/default.nix`.** Add a
   `writeShellApplication` named `nix-format`, with `runtimeInputs`
   `nix nixfmt coreutils findutils`. For each `.nix` argument it finds the
   nearest `flake.nix` above the file. If
   `nix eval <root>#formatter.<system> --apply 'x: true'` succeeds, it runs
   `timeout 30 nix fmt -- FILE`, otherwise `nixfmt FILE`. It always exits 0.
   `--stdin` resolves from `$PWD`, uses a `mktemp --suffix .nix`, formats
   that file and prints it. Register it in `pkgs/default.nix`.
   → Verify by `nix build .#…customPkgs.nix-format` (through the p620
   toplevel attribute), then run it on a scratch copy of a repo file, a
   file in a directory without a flake, and a file with a syntax error.
   Expected: `nixpkgs-fmt` style, `nixfmt` style, and exit 0 for all three.
2. **`home/development/nixd.nix`.** Rewrite it. Add an `osConfig ? null`
   argument. Remove `offlineMode`, `formatterCommand`, `diagnostics*` and
   `xdg.configFile."nixd/nixd.json"`. `hostName` defaults to
   `osConfig.networking.hostName` and falls back to `"p620"` when there is
   no `osConfig`. Install `pkgs.nixd`, `pkgs.customPkgs.nix-format` and a
   `nixd-agent` `writeShellScriptBin` that execs `nixd` with the three
   flags. `Users/olafkfreund/private.nix`: drop the removed option lines.
   → Verify by `just check-syntax`, then by checking that
   `nixd-agent --help` lists the flags and that the wrapper text contains
   `nixosConfigurations.p620`.
3. **`home/development/claude-code-lsp.nix`.** Change the plugin
   `lspServers` from `nil` to `nixd = { command = "nixd-agent";
   extensionToLanguage.".nix" = "nix"; }`, set the version to `1.1.0`,
   update the description, and rewrite the README (nixd, per-host options,
   formatting through a hook).
   → Verify by evaluating the rendered `marketplace.json` for p620 and
   checking that it contains `nixd-agent` and no `nil`.
4. **`modules/programs/claude-code-managed.nix`.** Change `formatScript` to
   run `${pkgs.customPkgs.nix-format}/bin/nix-format "$fp"`, and update the
   comment and the `formatOnEdit` description so they no longer name
   nixpkgs-fmt.
   → Verify by `just check-syntax` and checking that the rendered
   `managed-settings.json` PostToolUse command resolves to the new script.
5. **`home/syncthing-stignore.nix`.** Add a `/plugins/custom-marketplace`
   ignore line to the `.claude` block, before `!plugins/**` (the first match
   wins), with a one-line reason.
   → Verify with the rendered `.stignore`: the order is ignore line first,
   then the allowlist.
6. **`home/development/codex-cli.nix`.** Add `mcp-language-server` to
   `home.packages`. Add a `codex-nix-format` script with
   `writeShellScript`. It reads the hook JSON with `jq`, takes
   `.tool_input.command` (patch text) or `.tool_input.file_path`, and pulls
   the paths from `^\*\*\* (Add File|Update File|Move to):`. Relative paths
   are resolved against `.cwd`. `.nix` files are passed to `nix-format`,
   and the script exits 0. Add two activation entries after
   `writeBoundary`, each guarded with if/else and no `exit`:
   - `codexNixdMcp`: when `codex` exists and `codex mcp get nixd` fails, run
     `codex mcp add nixd -- mcp-language-server --workspace . --lsp nixd-agent`.
   - `codexNixFormatHook`: when the PostToolUse command for
     `codex-nix-format` is missing from `~/.codex/hooks.json`, append it
     with `jq` (matcher `apply_patch|Edit|Write`, timeout 30) and
     `install -m 0644` it back. The hook command is a stable
     `~/.local/bin/codex-nix-format` symlink target from `home.file`, so the
     jq entry never goes stale.

   → Verify by `just check-syntax` and a dry-run of the jq merge against a
   copy of today's `hooks.json`: herdr's `SessionStart` is kept and one
   PostToolUse entry is added. Running it a second time changes nothing.
7. **`docs/tooling/nix-lsp-agents.md` (new), `mkdocs.yml` and
   `mkdocs-full.yml`.** Write the page with these sections: overview table
   (agent, bridge, tools); `nixd-agent` and its flags; formatter selection;
   per-host options and the tracked-files-only caveat; the Home Manager
   limitation; verify; troubleshoot. Add
   `- Nix LSP for agents: tooling/nix-lsp-agents.md` under Tooling in both
   nav files.
   → Verify by markdownlint on the page and the repo's docs build or gate.
8. **Build all hosts.** Run `just test-host p620`, `just test-host razer`
   and `just test-host p510`.
   → Verify that all three build.
9. **Deploy p620 and run the checks.** Announce on the bus, then deploy p620
   only, then run the runtime checks below. razer and p510 are deployed
   only when you say so.
10. **Open the PR** linking intent, spec and plan, with `Closes #1983`.

## Tests

- `nix-format`: tested as in step 1.
- nixd: send an `initialize` to `nixd-agent`. Its stderr should show
  "evaluated nixos options" within about 60 s, with no eval errors. Record
  the RSS of each nixd process on p620.
- Claude Code: in a new session, `LSP hover` on `features.sunshine.enable`
  in `hosts/p510/configuration.nix` returns the option description. Also
  confirm with `claude --debug` that the server is `nixd-agent`.
- Claude format hook: an `Edit` that breaks indentation in a scratch `.nix`
  file under the repo is corrected, and `nixpkgs-fmt --check` then passes.
- Codex:
  - `codex mcp list` shows `nixd`;
  - a `diagnostics` request on a file with a deliberate error returns it;
  - an `apply_patch` to a `.nix` file comes back formatted;
  - the hook-trust prompt is accepted once.
- Syncthing: `/rest/db/ignores?folder=<claude>` lists
  `/plugins/custom-marketplace`.

## Rollback

- **Code:** `git revert` the implementation commits, then rebuild. Claude
  Code goes back to `nil` on its next start, because the marketplace is
  read live.
- **Codex:**
  - run `codex mcp remove nixd`;
  - delete the `codex-nix-format` entry from `~/.codex/hooks.json` with
    `jq`, since activation never removes it;
  - optionally remove the `[hooks.state]` trust line for it from
    `config.toml`.
- **Host:** `nixos-rebuild switch --rollback` on p620 covers the system
  side.
