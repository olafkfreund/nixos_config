---
status: draft
issue: 1835
intent: intent/2026-09-15-1835-npm-global-path-order.md
---

# Spec: tools installed by language package managers never shadow Nix packages

The decisions in the approved intent: Nix is the master, and duplicates are
deleted.

## Design

### Where the directories come from today (measured 2026-09-15)

| Shell | Source | Order today |
| --- | --- | --- |
| zsh login (p620) | `hm-session-vars.sh:74`, from `home.sessionPath` in `home/development/npm-prefix.nix:39` | `~/.local/bin`, `~/.npm-global/bin`, … the Nix profile at position 7. cargo and go are **not on PATH at all** |
| bash, including non-interactive `ssh razer cmd` | `home/shell/bash.nix:212-213` (`bashrcExtra`) | `~/.cargo/bin` 2, `~/.npm-global/bin` 3, `~/.local/bin` 5, `~/go/bin` 6, the Nix profile 13 |

### 1. Append the three directories instead of prepending them

A single appended order everywhere: **Nix profile → `~/go/bin` →
`~/.cargo/bin` → `~/.npm-global/bin`**. `~/bin` and `~/.local/bin` keep being
prepended, because Home Manager's `claude` launcher lives in `~/.local/bin`.

- **`home/development/npm-prefix.nix`:** remove `home.sessionPath = [ "${prefix}/bin" ];`.
  Put the append in the same file instead, so npm's prefix and its PATH entry
  stay together:

  ```nix
  home.sessionVariablesExtra = ''
    case ":$PATH:" in *":${prefix}/bin:"*) ;; *) export PATH="$PATH:${prefix}/bin" ;; esac
  '';
  ```

- **`home/development/languages.nix`** (next to `GOPATH`/`CARGO_HOME`, lines
  308-313): the same guarded append for `$HOME/go/bin`, then
  `$HOME/.cargo/bin`, through `home.sessionVariablesExtra`. zsh then gets the
  go and cargo tools too, after Nix, which it never had before.
- **`home/shell/bash.nix` `bashrcExtra`:** line 212 becomes
  `export PATH="$HOME/bin:$HOME/.local/bin:$PATH"`, and line 213 is replaced
  by the same guarded appends for the three directories.

  `bashrcExtra` is what non-interactive `ssh host cmd` shells read (its own
  comment says so), and they don't source `hm-session-vars.sh`. So the append
  has to exist there as well. The `case` guard stops an interactive login
  shell, which runs both, from adding a directory twice.

`sessionVariablesExtra` lines go into `hm-session-vars.sh`, which runs once
per session. `/etc/set-environment` has already put the Nix profile on PATH
before either file runs, so an append always lands after Nix.

### 2. Delete the duplicates on the hosts

This is runtime, not repo. It runs after the deploy, so nothing falls back to
a missing binary in between.

- **razer:** `cargo uninstall bottom fd-find globe-cli`, which removes `btm`,
  `fd` and `globe`. Nix provides all three: `/run/current-system/sw/bin/btm`,
  the per-user `fd`, and `/run/current-system/sw/bin/globe`.
- **Both hosts:** remove `~/.npm-global/lib/node_modules/@openai` (p620) and
  `@anthropic-ai` (razer), but only if they're empty. They were left behind by
  the earlier `npm uninstall -g`. If one isn't empty, list its contents in the
  PR and leave it.
- **p620:** has no duplicates (inventory 2026-09-15), so nothing is deleted
  there.
- **Rule for the future:** a duplicate is any file in the three directories
  whose command name also resolves in `/etc/profiles/per-user/$USER/bin` or
  `/run/current-system/sw/bin`. The plan's inventory script uses exactly this
  test, before and after.

## Alternatives rejected

- **Remove the three directories from PATH:** breaks the tools that exist
  only there (npm `jshint`, `neovim-node-host`; cargo `sqlx`, `cross`,
  `avatarsay`, `zoe`; go `golangci-lint`, `gosec`, `spofi`…).
- **Keep prepending and just delete the duplicates:** the next
  `cargo install` or `npm i -g` shadows Nix again. That is the recurrence the
  intent rules out.
- **Package every language-manager tool in Nix and drop the directories:** it
  is the right long-term answer for tools that are used a lot, but it's a
  per-tool project and not needed for "Nix wins". Tools can move one at a
  time later.
- **`home.sessionSearchVariables.PATH`:** it prepends, like `sessionPath`.
- **A wrapper or alias per duplicate:** fixes only the names we know about.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| A tool you use from npm, cargo or go is now hidden by an older Nix copy of the same name | p620, razer | Intended (Nix is master). Only `btm`, `fd` and `globe` collide on razer, and those copies get deleted. A new collision needs a newer Nix copy, not a PATH change |
| An ssh non-interactive shell loses a directory because the `bashrcExtra` edit is wrong | razer (remote commands, deploy scripts) | Test 3: `ssh razer 'command -v jshint sqlx staticcheck'` resolves after the deploy |
| The guard leaves a directory out entirely | all | Test 2 checks each directory is present exactly once, in every shell kind |
| `cargo uninstall` removes something shared | razer | Each crate installs only its own binaries (`cargo install --list` shows `btm`, `fd` and `globe`); nothing else depends on them |
| p510 picks up the new order at its next deploy | p510 | No npm, cargo or go tools there are known to matter; it isn't deployed for this |

## Verification

1. **Build:** `just check-syntax`, `just test-host p620`, `just test-host
   razer`, and p510 evaluation only.
2. **Order in every shell kind,** on both hosts after the deploy. Kinds: zsh
   login (`env -i … zsh -lic`), bash login (`bash -lic`), bash interactive
   (`bash -ic`) and non-interactive ssh (`ssh host 'echo $PATH'`). In each:
   - the index of `/etc/profiles/per-user/$USER/bin` is lower than the index
     of each of `~/go/bin`, `~/.cargo/bin` and `~/.npm-global/bin`
   - each of those three appears exactly once
   - `~/.local/bin` is still before the Nix profile
3. **npm/cargo/go-only tools still resolve:** razer `command -v jshint
   neovim-node-host sqlx cross zoe staticcheck spofi` all resolve (bash login
   and ssh). p620: `command -v golangci-lint tokio-console` resolve.
4. **No duplicates:** the plan's inventory script prints no `DUP` line on
   either host, and `cargo install --list` on razer has no `bottom`, `fd-find`
   or `globe-cli`.
5. **Nix wins:** razer `type -a -p fd btm globe claude` → the first hit for
   each is a Nix path (for `claude`, `~/.local/bin/claude`, the HM link).
6. **Recurrence check:** on razer, `npm i -g prettier`. Nix already provides
   `prettier` there (`home/development/codex-cli.nix`). Then `type -a -p
   prettier` must list the Nix copy first. Clean up with
   `npm uninstall -g prettier`.
