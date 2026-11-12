---
status: draft
issue: 2874
spec: spec/2026-11-12-2874-remove-gogmail.md
coders:
  1: coder   # deletes the input and overlay and relocks; ordinary edit plus one command
  2: coder   # four deletions in one Nix file; mechanical, but the list syntax must survive
  3: coder   # comment rewording in three files; no logic
reviewers:
  - codex    # independent read of the diff against this plan (agy retired, #2748)
---

# Plan: Remove gogmail from the config

Self-contained summary of the approved decisions:

- Remove the gogmail TUI completely: the flake input, its 4 lock nodes, the
  overlay, the package, the `gogmail-tmux` wrapper, the `M-c` bind, and the
  which-key and palette entries. Reword every comment that names it.
- **The gog CLI stays.** `pkgs/gogcli`, `programs.gogDashboard`
  (`home/shell/gogcli`), the `gogcli-*` agenix secrets and `gogWrapped` keep
  working. In those files, only comments change.
- `M-c` is left unbound. No `unbind-key` line is added: running tmux servers
  keep the old bind until they restart, and that goes in the PR text.
- The `olafkfreund/gogmail` repo, `gogmail#29` and user state under `$HOME`
  are not touched.
- No new option, no flag. Explicit imports only.
- p510 is evaluated, never built or deployed in this task.

Baseline for checks is `origin/main` at `f1910be2e`. Line numbers below
are from that commit. Work happens in the worktree
`/home/olafkfreund/.config/nixos-2874`, branch `chore/2874-remove-gogmail`.
Never work in `~/.config/nixos`.

## Steps

1. **Flake input, overlay, lock**
   - `flake.nix:197-202`: delete the six lines starting at
     `# GogMail — keyboard-driven Google Workspace TUI` and ending with
     `gogmail.url = "github:olafkfreund/gogmail";`. Keep one blank line
     between the Claude Desktop note above and the
     `# Claude Code skill catalogue (borghei)` comment below.
   - `overlays/default.nix:7-9`: delete the whole overlay function
     `(_final: prev: { gogmail = inputs.gogmail.packages.${prev.stdenv.hostPlatform.system}.gogmail; })`
     and the blank line after it, so the list has no empty overlay.
   - Run `nix flake lock`.

   → verify: the first command prints `[]`, the diff prints nothing:

   ```bash
   nix flake metadata --json \
     | jq '.locks.nodes | keys | map(select(test("gogmail|flake-utils_2|nixpkgs_2|systems_2")))'
   diff \
     <(git show f1910be2e:flake.lock \
       | jq -S '.nodes | del(.gogmail, ."flake-utils_2", .nixpkgs_2, .systems_2)
                | del(.root.inputs.gogmail)') \
     <(jq -S .nodes flake.lock)
   ```

   Traps: if `nix flake lock` updates any other node (a missing `locked`
   for something else), stop and report; do not run `nix flake update`.
   Step 1 alone leaves `pkgs.gogmail` dangling in tmux, so do not
   evaluate until step 2 is done.

2. **tmux** (`home/shell/tmux/default.nix`)
   - 194-197: delete the 3-line `# M-c → GogMail TUI …` comment and
     `bind-key -n M-c     display-popup … 'gogmail-tmux'`. The blank line
     before `# ========== Terminal and Display Settings ==========` stays.
   - 364-367: replace the 4-line `# Path + clock. (The former gog …)`
     comment with the single line
     `# Path + clock. (The former gog Google-Workspace status segments were removed.)`
   - 514-516: delete the three string lines
     `"      - name: GogMail (Google Workspace TUI)"`, `"        key: m"`
     and `"        command: display-popup … 'gogmail-tmux'"`. The
     `"      - separator: true"` line after them stays.
   - 608-613: delete the last list element, from `{` with
     `icon = "󰇮";` through its closing `}`. The previous element's `}` is
     then directly followed by `]);`.
   - 618-638: delete the `# GogMail — Google Workspace TUI …` comment, the
     `pkgs.gogmail` line, the blank line, the `# gogmail launch wrapper …`
     comment and the whole `(pkgs.writeShellApplication { name = "gogmail-tmux"; … })`
     through its `})`, plus the blank line after it. `home.packages = [`
     is then followed by `pkgs.customPkgs.tmux-ccm`.

   → verify: `git grep -n -i gogmail -- home/shell/tmux` is empty,
   `nix-instantiate --parse home/shell/tmux/default.nix >/dev/null` succeeds,
   and `nix eval --raw .#nixosConfigurations.p620.config.system.build.toplevel.drvPath`
   evaluates.
   Traps: the which-key block is a Nix list of YAML strings, so keep its
   indentation exactly. The palette list ends `]);`, not `]`.

3. **Comments in the gog CLI files**
   - `home/shell/gogcli/default.nix:22-27`: drop the sentence
     `Same pattern as gogmail-tmux in home/shell/tmux.` and rejoin the
     paragraph, so it reads "…the password lives in agenix rather than the
     session environment. Falls through untouched when the secret is
     absent, so an interactive shell still gets the normal password prompt."
   - `home/shell/gogcli/default.nix:89-90`: the description becomes
     "Exported as GOG_KEYRING_PASSWORD by the import service (to seed the
     keyring) and by the gog wrapper (to read it). Runtime only."
   - `modules/secrets/api-keys.nix:205-206`: the comment becomes
     `# Password for gog's file keyring backend — read by gog-token-import (to`
     `# seed the keyring) and the gog wrapper (to read it at runtime).`
   - `pkgs/gogcli/default.nix:24-31`: delete the whole paragraph from
     `# Bumping this does NOT update every gog on the machine. gogmail is a flake`
     through `# this derivation.`, and the `#` line before it if that would
     leave two blank comment lines together.

   → verify: `git grep -n -i gogmail -- ':!intent' ':!spec' ':!plan'`
   is empty, and the gog drvPath equals the baseline:
   `nix eval --raw .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.gogDashboard.package.drvPath`
   prints `/nix/store/s8hi5w7lfiwgvv2hx483vyi1p21sya65-gogcli-0.48.0.drv`.
   Traps: comments only. Do not touch any option default, secret path or
   attribute. The description string is part of the HM option docs, so its
   change is expected and harmless.

4. **Verify and commit** (lead)
   - Run the Tests below.
   - Commit steps 1-3 as one commit
     `chore(gogmail): remove gogmail from the config (#2874)` (the overlay
     and input must land together). Push, then check that the remote head
     matches.
   - Open the PR linking the intent, spec and plan, with a note about
     running tmux servers. Post `@codex review`.

## Tests

| # | Command | Expected |
|---|---|---|
| 1 | `git grep -n -i gogmail -- ':!intent' ':!spec' ':!plan'` | no output |
| 2 | lock diff from step 1 | empty |
| 3 | `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` for p620, razer, p510 | succeeds; the only warning is `sourceHighlight` |
| 4 | gog drvPath from step 3 | equals baseline |
| 5 | `just test-host p620`; `nix build --no-link --print-out-paths .#nixosConfigurations.razer.config.system.build.toplevel` | both build |
| 6 | `nix path-info -r <out> \| grep -i gogmail` for p620 and razer | no output |
| 7 | in `home-files/` of `nix build --no-link --print-out-paths .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.activationPackage`: `grep -n 'M-c\|gogmail' .config/tmux/tmux.conf`; `grep -c GogMail` on `.config/tmux/plugins/tmux-which-key/config.yaml` and `.config/tmux-palette/palettes/ai-tools.json`; `yq .` / `jq .` parse them | no matches, 0, 0; both parse |

All builds run on p620. razer is never built on razer itself.

## Rollback

`git revert` the implementation commit alone. That restores `flake.nix`,
the overlay, tmux and the original `flake.lock` pin together. Don't run
`nix flake lock` or check out a lock from a later `origin/main`. Nothing
on the hosts changes until a deploy, and a deploy rolls back with the
previous NixOS generation.
