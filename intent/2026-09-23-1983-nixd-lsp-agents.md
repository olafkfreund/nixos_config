---
status: draft
issue: 1983
author: olafkfreund
---

# Intent: nixd + nixfmt as the Nix language server for Claude Code and Codex

## Problem

The two coding agents see Nix code differently, and neither setup is the one
we want.

- **Claude Code** runs `nil` through the local `nix-lsp` plugin in
  `home/development/claude-code-lsp.nix`. It has no idea which NixOS or
  Home Manager options exist, so it cannot check an option path. The
  plugin's README says it does "formatting with nixpkgs-fmt", but that is
  not true: nothing is wired up.
- **Codex** has no language server of any kind. Codex CLI 0.155.1 has no
  native LSP support, so its only view of Nix is text search.
- **Formatting** is not done by either agent. Research found that neither
  agent ever sends an LSP formatting request. Claude Code's `LSP` tool
  offers definition, references, hover, symbols and call hierarchy, but not
  formatting. Codex's LSP bridge (`mcp-language-server`) offers definition,
  references, diagnostics, hover, rename and edit, but not formatting either.
  So `nixd.formatting.command = ["nixfmt"]` only has an effect in an editor.
  An agent formats a file only if a post-edit hook runs the formatter.

## Proposed outcome

- Both Claude Code and Codex use `nixd` (from `pkgs.nixd`) as their Nix
  language server. That covers diagnostics, hover, definitions, references,
  and knowledge of the options in this flake.
- A `.nix` file that either agent edits comes out formatted by `nixfmt`,
  without anyone asking for it.
- The whole thing is declared in Nix. A fresh host gets it on its first
  rebuild, with no hand-edited `~/.claude` or `~/.codex` files.
- One page under `docs/` explains the setup: what each agent can do with
  the server, and why formatting runs through hooks. That page is linked
  from both `mkdocs.yml` and `mkdocs-full.yml`.

## Affected users and systems

- Hosts: p620 and razer, which both import `home/development/`. p510 also
  runs claude-code (see memory); whether it has Codex and this module is
  checked at spec time.
- Files: `home/development/claude-code-lsp.nix`,
  `home/development/codex-cli.nix` and `codex-cli/module.nix`, plus the
  Claude and Codex hook configuration, and `docs/`.
- New package: `mcp-language-server` (nixpkgs 0.1.1), the MCP bridge Codex
  needs.

## Constraints

- `~/.claude` and `~/.codex` are syncthing-synced and changed by the agents
  at runtime, so no nix-store symlinks for their files. Use the existing
  seed or merge pattern.
- `~/.codex/config.toml` is currently hand-managed, including all of its
  `mcp_servers` entries. Adding an entry must not clobber the existing ones.
- Changes are Home Manager only. No service is involved, so the
  systemd-hardening rules don't apply.
- p510 must not be built or deployed without asking.

## Open questions

1. **nixfmt vs the repo standard.** This repo formats with `nixpkgs-fmt`
   (`flake.nix` `formatter`, and `.pre-commit-config.yaml`). If agent hooks
   run `nixfmt` here, every agent edit reformats the file in a different
   style, and the pre-commit hook then reformats it back. Pick one:
   - **A.** Move the repo to nixfmt: switch the flake formatter and
     pre-commit, and do one bulk reformat under its own issue, before or
     alongside this one.
   - **B.** Hooks run `nixfmt` only outside repos that pin another
     formatter. In this repo they run whatever `nix fmt` resolves to.
   - **C.** Hooks always run `nixfmt`, and we accept the churn in this repo.
2. **Keep `nil` alongside nixd?** Claude Code runs one server per file
   extension. The proposal replaces `nil` with `nixd`.
3. **Option completion target.** nixd needs one host's configuration to
   know which options exist, for example
   `nixosConfigurations.p620.options`. Should that be p620 everywhere, or
   each host's own?
4. **Codex scope.** Should Codex get the language server on p620 and razer
   only, or on every host where Codex is installed?
