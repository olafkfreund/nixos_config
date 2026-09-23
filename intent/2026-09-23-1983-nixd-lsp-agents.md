---
status: approved
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

## Decisions

Approved 2026-09-23. The original four open questions are resolved as follows:

1. **Formatter follows the repo.** Agent hooks format with whatever the repo
   uses: `nixpkgs-fmt` in this repo, and `nixfmt` only where a repo sets
   nothing. There is no bulk reformat. nixd's `formatting.command` follows
   the same rule.
2. **nixd replaces nil** as the Claude Code Nix server.
3. **Each host's own options.** nixd reads option completion from
   `nixosConfigurations.<this host>`.
4. **Codex gets the server on every host** where Codex is installed.
