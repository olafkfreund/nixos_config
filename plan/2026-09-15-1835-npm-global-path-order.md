---
status: draft
issue: 1835
spec: spec/2026-09-15-1835-npm-global-path-order.md
---

# Plan: tools installed by language package managers never shadow Nix packages

Branch `fix/1835-npm-global-path-order` (worktree `../nixos-1835`, merged
with `main` at `c3ad22f74`). Hosts are p620 and razer. p510 is evaluated only.

## Approved decisions

These are carried over from the intent and spec.

**D1. Nix is the master.** No npm, cargo or go copy may override a Nix
command, and duplicates are deleted. Tools that exist only in those
directories stay reachable.

**D2. One order in every shell:** `~/bin`, `~/.local/bin` and
`~/.config/rofi/scripts` stay prepended as today (the HM `claude` launcher
lives in `~/.local/bin`). Then comes the system PATH with the Nix profiles,
then `~/go/bin`, `~/.cargo/bin` and `~/.npm-global/bin`, **appended**. Each
append is guarded, so a directory is never added twice:

```sh
case ":$PATH:" in *":DIR:"*) ;; *) export PATH="$PATH:DIR" ;; esac
```

**D3. Where the appends live:**

- `home/development/npm-prefix.nix`: delete `home.sessionPath = [ "${prefix}/bin" ];`
  (line 39) and add a `home.sessionVariablesExtra` guarded append for
  `${prefix}/bin`.
- `home/development/languages.nix`: next to `GOPATH`/`CARGO_HOME`
  (lines 307-314), add
  `home.sessionVariablesExtra = mkMerge [ (mkIf cfg.languages.go.enable <go append>) (mkIf cfg.languages.rust.enable <cargo append>) ];`,
  using `$HOME/go/bin` and `$HOME/.cargo/bin`. These end up in
  `hm-session-vars.sh`, which `~/.profile` and `~/.zshenv` source.
- `home/shell/bash.nix` `bashrcExtra` (lines 211-215): line 212 becomes
  `export PATH="$HOME/bin:$HOME/.local/bin:$PATH"`, and line 213 is replaced
  by the three guarded appends in D2 order. The rofi line stays. Non-interactive
  `ssh host cmd` shells read only this.

**D4. Duplicates are removed after the deploy.**

- razer: `cargo uninstall bottom fd-find globe-cli`.
- Empty `~/.npm-global/lib/node_modules/@openai` (p620) and `@anthropic-ai`
  (razer) are removed with `rmdir`, which refuses on a non-empty directory. If
  one isn't empty, record what's in it in the PR and leave it.
- p620 has no duplicates.
- A duplicate is a file in one of the three directories whose name resolves in
  `/etc/profiles/per-user/$USER/bin` or `/run/current-system/sw/bin`.

**D5. Rejected, do not reintroduce:**

- removing the directories from PATH
- keeping the prepend and only deleting duplicates
- packaging every tool now
- `home.sessionSearchVariables.PATH` (it prepends)
- per-command aliases

## Scripts used by the steps (session scratchpad, not committed)

`dup-inv.sh` (read-only; already written and run on 2026-09-15). For each
file in `~/.npm-global/bin`, `~/.cargo/bin` and `~/go/bin`, it prints `DUP`
when `PATH=/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin command -v <name>`
resolves.

`path-order.sh` (read-only, new). It takes a PATH string on stdin and prints
`OK` or `FAIL` with a reason. It checks that:

- the index of `/etc/profiles/per-user/$USER/bin` < the index of each of
  `$HOME/go/bin`, `$HOME/.cargo/bin` and `$HOME/.npm-global/bin`
- each of those three appears at most once
- `$HOME/.local/bin` comes before the Nix profile

## Steps

1. **`home/development/npm-prefix.nix`:** D3 (drop `sessionPath`, add the
   append). Update the file's comment to say why it's an append.
   → verify: the evaluated `home.sessionVariablesExtra` for p620 contains
   `.npm-global/bin`, and `home.sessionPath` no longer does.
2. **`home/development/languages.nix`:** D3, the go and cargo appends.
   → verify: the same eval contains `go/bin` and `.cargo/bin` (both languages
   are enabled on p620; check with
   `config.home-manager.users.olafkfreund.<cfg path>.languages.{go,rust}.enable`).
3. **`home/shell/bash.nix`:** D3 `bashrcExtra`.
   → verify: after the build, the generated `~/.bashrc` in the home-files
   output has no `.npm-global/bin:$PATH` or `.cargo/bin:` prepend, and has the
   three `case` appends.
4. **Commit** 1–3 as
   `fix(shell): append npm/cargo/go bin dirs after Nix on PATH (#1835)`.
   → verify: pre-commit hooks pass.
5. **Build:** confirm the branch is current with `origin/main` (merge if not),
   then `just check-syntax`, `just test-host p620`, `just test-host razer`, and
   evaluate p510's `home.sessionVariablesExtra` (evaluation only).
   → verify: all succeed.
6. **Deploy:** read the bus and post first, then `just quick-deploy p620` and
   `just deploy-via-p620 razer` with `AGENT_BUS_ANNOUNCED=1`.
   → verify: no failed units, `home-manager-olafkfreund` active on both hosts.
7. **Remove duplicates (D4)** on razer: `cargo uninstall bottom fd-find
   globe-cli`. On both hosts, `rmdir` the leftover npm scope directories.
   → verify: `dup-inv.sh` prints no `DUP` on either host.
8. **Run the tests below**, then push and open a PR linking the intent, spec
   and plan, with `Closes #1835`.

## Tests

The shell kinds on each host: zsh login
(`env -i HOME=$HOME USER=$USER TERM=xterm zsh -lic 'echo $PATH'`), bash login
(`bash -lic`), bash interactive (`bash -ic`), and non-interactive ssh
(`ssh host 'echo $PATH'`; from p620 to razer, and `ssh p620` from itself as a
local stand-in).

| # | Command | Expected |
| --- | --- | --- |
| T1 | Step 5 | Pass |
| T2 | `path-order.sh` for each shell kind, on both hosts | `OK` ×8 |
| T3 | razer, bash login and ssh: `command -v jshint neovim-node-host sqlx cross zoe staticcheck spofi`; p620: `command -v golangci-lint tokio-console` | All resolve |
| T4 | `dup-inv.sh` on both hosts; razer `cargo install --list` | No `DUP`; no bottom, fd-find or globe-cli |
| T5 | razer bash login: `type -a -p fd btm globe claude` | First hit for each is Nix (`claude` → `~/.local/bin/claude`, the HM link) |
| T6 | razer: `npm i -g prettier`, then `type -a -p prettier`, then `npm uninstall -g prettier` | The first hit is `/etc/profiles/per-user/olafkfreund/bin/prettier`; the probe is cleaned up |

## Rollback

- **Before merge:** close the PR, then redeploy both hosts from `main`.
- **After merge:** `git revert` the step-4 commit and redeploy p620 and razer.
  The PATH order comes back at the next login.
- **Removed cargo tools:** Nix provides all three, so nothing is lost. If one
  is ever needed from cargo again, `cargo install bottom` (or `fd-find`,
  `globe-cli`).
