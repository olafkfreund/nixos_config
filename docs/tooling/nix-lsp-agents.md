# Nix LSP for coding agents

Claude Code and Codex both use [nixd](https://github.com/nix-community/nixd) as their Nix language
server. Each agent edits `.nix` files with the repo's own formatter. The setup is the same on every host
that imports `home/development` (p620, razer and p510), and it is fully declarative. Issue:
[#1983](https://github.com/olafkfreund/nixos_config/issues/1983).

## At a glance

| Agent       | How it reaches nixd                                         | What it can do                                                        | Formatting                               |
| ----------- | ----------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------- |
| Claude Code | `nix-lsp` plugin → `nixd-agent`                             | `LSP` tool: hover, definition, references, symbols, call hierarchy; diagnostics pushed after every edit | Managed PostToolUse hook → `nix-format`  |
| Codex       | MCP server `nixd` → `mcp-language-server` → `nixd-agent`   | MCP tools `hover` and `diagnostics` (plus `rename_symbol`, `edit_file`); `definition` and `references` return an error, see below | `~/.codex/hooks.json` PostToolUse → `nix-format` |

## The pieces

| File                                      | Provides                                                                   |
| ----------------------------------------- | -------------------------------------------------------------------------- |
| `pkgs/nix-format/default.nix`             | `nix-format`, the repo-aware formatter                                     |
| `home/development/nixd.nix`               | `nixd-agent`, nixd with this host's flags                                  |
| `home/development/claude-code-lsp.nix`    | The `nix-lsp` plugin in the local `nixos-lsp-marketplace`                  |
| `modules/programs/claude-code-managed.nix`| Claude's format-on-edit hook (`formatOnEdit.enable`)                       |
| `home/development/codex-cli.nix`          | `mcp-language-server`, the Codex MCP registration and the Codex hook       |

## nixd-agent

nixd 2.x reads no config file. It takes settings through the LSP `workspace/configuration` request or
through command-line flags. Neither Claude Code nor `mcp-language-server` is known to answer that
request (confirmed for Claude Code), so `nixd-agent` passes everything as flags, which work with any client:

```text
nixd --nixos-options-expr='(builtins.getFlake "git+file://<flakeDir>").nixosConfigurations.<host>.options'
     --nixpkgs-expr='import (builtins.getFlake "git+file://<flakeDir>").inputs.nixpkgs { }'
     --config='{"formatting":{"command":["nix-format","--stdin"]}}'
```

- `<host>` defaults to the host's own `networking.hostName`, so each host completes and describes its own
  options.
- `<flakeDir>` defaults to `~/.config/nixos`. Both are options under `development.nixd`.
- `options` cannot go into `--config`: nixd only starts option workers from the dedicated flag or from a
  `workspace/configuration` reply.
- Both agents launch the wrapper by name, so the synced plugin file is identical on every host. The
  per-host values live only in the wrapper on that host's `PATH`.

The first evaluation of the option set takes 30 to 60 seconds in the background, and nixd works without
it in the meantime. A running nixd takes about 350 MB: the server plus its nixpkgs and NixOS option
workers. Each agent session starts its own.

### The nixd patch

nixd 2.9.2 does not answer a request it does not implement with `-32601 method not found`, as LSP
requires. It ends its message loop and exits instead (`nixd/lspserver/src/LSPServer.cpp`, `onCall`).
`mcp-language-server` sends two such requests:

- its `diagnostics` tool asks for pull diagnostics (`textDocument/diagnostic`);
- `definition` and `references` look a symbol up by name through `workspace/symbol`.

Without a fix, each of those calls killed nixd, and the Codex session hung waiting on a dead server.
`home/development/nixd-method-not-found.patch` makes nixd reply `MethodNotFound`. It is applied only to
the nixd that `nixd-agent` runs, by `overrideAttrs` rather than an overlay, so nothing else loses its
binary-cache hits. `diagnostics` now works. `definition` and `references` return a clean error, because
nixd has no workspace-symbol index to look names up in. Claude Code is unaffected either way: it reads
pushed diagnostics and resolves definitions by position.

## Formatting

Neither agent ever sends an LSP formatting request. Claude's `LSP` tool has no formatting operation, and
`mcp-language-server` exposes none. Formatting therefore runs from post-edit hooks. Both hooks call
`nix-format`, which:

1. walks up from the edited file to the nearest `flake.nix`;
2. runs `nix fmt -- FILE` if that flake has a `formatter.<system>` output (`nixpkgs-fmt` in this repo);
3. otherwise runs `nixfmt FILE`;
4. always exits 0, so it never breaks the edit that triggered it.

This way an agent never reformats a repo in a style its pre-commit hook would undo. nixd's own
`formatting.command` is `nix-format --stdin`, so an editor that asks nixd to format gets the same result.

## Limitations

- **Tracked files only.** `getFlake "git+file://…"` sees only what git tracks. A new module is invisible
  to option completion until it is `git add`-ed.
- **No Home Manager option completion.** It can only be configured through `workspace/configuration`.
  Claude Code does not answer that request (nixd logs "client does not support workspace
  configuration"), and `mcp-language-server` is not known to.
- **Codex asks once per host** to trust the new hook. Accept the prompt. It also asks before each nixd
  MCP tool call, as it does for any MCP tool.
- **No name-based lookup in Codex.** `definition` and `references` need `workspace/symbol`, which nixd
  does not implement. Use `hover` plus a text search instead.

## Verify

```bash
nixd-agent --help | grep nixos-options-expr   # the wrapper exists
codex mcp get nixd                             # Codex has the MCP server
jq '.hooks.PostToolUse' ~/.codex/hooks.json    # Codex has the format hook
```

In Claude Code, run `LSP hover` on a leaf option, such as the `enable` in
`services.nixarchy-runner = { enable = true; }` in `hosts/p620/configuration.nix`. It should return
`bool (boolean)` and the option's description. A set of options (`services.nixarchy-runner` itself) shows
`? (missing type)`, which is normal nixd behaviour, not a fault.

## Troubleshooting

- **Claude reports no LSP server for `.nix`.** Check that `nix-lsp@nixos-lsp-marketplace` is enabled in
  `~/.claude/settings.json`, then restart the session. The marketplace is read live, so no reinstall is
  needed after a rebuild. `claude --debug` logs the server start.
- **Options are missing from hover or completion.** Run
  `nix eval ~/.config/nixos#nixosConfigurations.$(hostname).options --apply builtins.attrNames`. If that
  fails, nixd's option worker fails too.
- **Codex has no `nixd` tools.** Check `codex mcp list`. Re-running home-manager activation adds the
  server again after a `codex mcp remove nixd`.
- **An edit was not formatted.** Run `nix-format FILE` by hand. It is silent by design, so remove the
  redirects in a copy of the script to see the error.
