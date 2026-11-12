---
status: draft
issue: 2874
intent: intent/2026-11-12-2874-remove-gogmail.md
---

# Spec: Remove gogmail from the config

## Design

Delete gogmail at every point where it enters the config, and reword the
comments in the gog CLI files that name it. No replacement, no new option.

Open questions in the approved intent, resolved by the owner's approval
without answers, so the defaults apply:

1. `M-c` is unbound. No rebind in this change.
2. The `olafkfreund/gogmail` repo and `gogmail#29` are left untouched.
3. User state under `$HOME` is left alone.

Changes, by file (line numbers from `origin/main` at `f1910be2e`):

| File | Change |
| ---- | ------ |
| `flake.nix:197-202` | Delete the `gogmail.url` input and its 5-line comment (the blank line above stays). |
| `flake.lock` | `nix flake lock` prunes `gogmail`, `flake-utils_2`, `nixpkgs_2` and `systems_2`, and nothing else. |
| `overlays/default.nix:7-9` | Delete the whole `(_final: prev: { gogmail = …; })` overlay. It holds only that line, so no empty overlay is left behind. |
| `home/shell/tmux/default.nix:194-197` | Delete the `M-c` comment and `bind-key -n M-c …gogmail-tmux`. |
| `home/shell/tmux/default.nix:364-367` | Rewrite the whole comment as one line: `# Path + clock. (The former gog Google-Workspace status segments were removed.)` |
| `home/shell/tmux/default.nix:514-516` | Delete the which-key `GogMail` entry (`key: m`). |
| `home/shell/tmux/default.nix:608-613` | Delete the `GogMail (Popup)` attrset from the AI-tools palette list. |
| `home/shell/tmux/default.nix:618-638` | Delete `pkgs.gogmail`, its comment, and the whole `gogmail-tmux` `writeShellApplication` through its closing `})` at 638. `pkgs.customPkgs.tmux-ccm` and the rest of the list stay. |
| `home/shell/gogcli/default.nix:22-27` | Rewrite the comment to drop "Same pattern as gogmail-tmux in home/shell/tmux." and keep the rest of the sentence flow intact. |
| `home/shell/gogcli/default.nix:90` | Option description: exported "by the import service (to seed the keyring)", without the gogmail launcher. |
| `modules/secrets/api-keys.nix:205-206` | Comment: the secret is read by `gog-token-import` and the `gog` wrapper. |
| `pkgs/gogcli/default.nix:24-31` | Delete the whole paragraph about gogmail pinning its own gogcli, through "…agenix token import use this derivation." Nothing else holds a second gogcli now. |

The overlay and the input go in the same commit, because either one alone
leaves a dangling reference (`inputs.gogmail` or `pkgs.gogmail`).

## Alternatives rejected

- **Disable only** (drop it from `home.packages` but keep the input):
  rejected by the intent, which asks for full removal. It would also keep
  fetching and locking a second nixpkgs.
- **A `features.gogmail.enable` flag set to false:** adds an option for
  something nobody uses, against the ponytail rule.
- **Rebind `M-c` now:** no target was given. Unbound is the approved
  default.
- **Emit `unbind-key -n M-c` in tmux.conf** to clear it on running servers:
  rejected. It is a permanent line to fix a one-time transition; a new tmux
  server is enough (see Risks).

## Risks

- **The which-key menu YAML is a string list.** Deleting three lines from
  the middle keeps it valid. The next `separator` still sits between two
  entries. Checked by reading back the generated file.
- **Running tmux servers keep `M-c`.** `bind r` only `source-file`s the new
  config, and omitting a bind does not remove it. Until the tmux server
  restarts (logout, reboot or `tmux kill-server`), `M-c` still runs
  `gogmail-tmux`, which no longer exists, so the popup shows "command not
  found". Once the server is new, Alt-c reaches the application. This is
  noted in the PR. No code is added for it.
- **`nixpkgs_2` might be shared.** The lock check showed it is used only by
  gogmail. If `nix flake lock` changes any other node, that is a stop.
- **gogcli rebuild:** none. Only comments change in `pkgs/gogcli`, so the
  derivation is identical. Verified by drvPath.
- **p510:** it evaluates only. It is built only with the owner's OK, and its
  closure stays unverified until then.

## Verification

Baseline values are taken from `origin/main` (`/home/olafkfreund/.config/nixos`
is not used, because its `flake.lock` is dirty). This uses a detached
worktree at `origin/main`, or `git+file://…?ref=main`.

1. `git grep -n -i gogmail -- ':!intent' ':!spec' ':!plan'` returns nothing.
2. `git diff origin/main -- flake.lock` removes exactly the four nodes, and
   no other node's `locked` changes:
   `jq -S '.nodes | del(.gogmail, ."flake-utils_2", .nixpkgs_2, .systems_2) | del(.root.inputs.gogmail)'`
   on the old lock equals `jq -S .nodes` on the new one.
3. For p620, razer and p510:
   `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
   succeeds, and the only warning is the known `sourceHighlight` one
   (until nixarchy#1762 lands).
4. The gog CLI is unchanged:
   `nix eval --raw .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.programs.gogDashboard.package.drvPath`
   equals the baseline (`/nix/store/s8hi5w7lfiwgvv2hx483vyi1p21sya65-gogcli-0.48.0.drv`
   on `origin/main`).
5. `just test-host p620` builds. razer's toplevel is built on p620 with
   `nix build .#nixosConfigurations.razer.config.system.build.toplevel`.
   p510 is eval only, unless the owner OKs a build.
6. Closures: `nix path-info -r <toplevel> | grep -i gogmail` is empty for
   the p620 and razer outputs from step 5.
7. Generated files in p620's HM generation, read from `home-files/` under
   `nix build --no-link --print-out-paths .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.activationPackage`:
   - `home-files/.config/tmux/tmux.conf`: no `M-c` and no `gogmail`
   - `home-files/.config/tmux/plugins/tmux-which-key/config.yaml`: no
     `GogMail`, and it parses (`yq . <file>`)
   - `home-files/.config/tmux-palette/palettes/ai-tools.json`: no `GogMail`,
     and it parses (`jq . <file>`)
