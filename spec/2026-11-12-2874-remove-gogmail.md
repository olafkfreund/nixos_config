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
| `flake.nix:197-202` | Delete the `gogmail.url` input and its 5-line comment. |
| `flake.lock` | `nix flake lock` prunes `gogmail`, `flake-utils_2`, `nixpkgs_2` and `systems_2`, and nothing else. |
| `overlays/default.nix:8` | Delete the `gogmail = inputs.gogmail…` line. |
| `home/shell/tmux/default.nix:194-197` | Delete the `M-c` comment and `bind-key -n M-c …gogmail-tmux`. |
| `home/shell/tmux/default.nix:365-366` | Reword the status-bar comment: the gog segments were removed, with no reference to gogmail. |
| `home/shell/tmux/default.nix:514-516` | Delete the which-key `GogMail` entry (`key: m`). |
| `home/shell/tmux/default.nix:608-613` | Delete the `GogMail (Popup)` attrset from the AI-tools palette list. |
| `home/shell/tmux/default.nix:618-637` | Delete `pkgs.gogmail` and the `gogmail-tmux` `writeShellApplication` from `home.packages`. |
| `home/shell/gogcli/default.nix:25` | Comment: drop "Same pattern as gogmail-tmux in home/shell/tmux." |
| `home/shell/gogcli/default.nix:90` | Option description: "read by the import service", without the gogmail launcher. |
| `modules/secrets/api-keys.nix:206` | Comment: the secret is read by `gog-token-import` and the `gog` wrapper. |
| `pkgs/gogcli/default.nix:24-28` | Delete the note that gogmail pins its own gog. Nothing else does now. |

Removing the overlay line and the input together matters: either one alone
leaves a dangling reference, either `inputs.gogmail` or `pkgs.gogmail`.

## Alternatives rejected

- **Disable only** (drop it from `home.packages` but keep the input):
  rejected by the intent, which asks for full removal. It would also keep
  fetching and locking a second nixpkgs.
- **A `features.gogmail.enable` flag set to false:** adds an option for
  something nobody uses, against the ponytail rule.
- **Rebind `M-c` now:** no target was given. Unbound is the approved
  default.

## Risks

- **The which-key menu YAML is a string list.** Deleting three lines from
  the middle can break indentation or leave a dangling `separator`. The
  block is checked after the edit, and the generated menu file is read
  back from the HM build.
- **Pressing `M-c` in tmux** falls through to the application, so a TUI
  that uses Alt-c now receives it. That is the expected effect of
  unbinding.
- **`nixpkgs_2` might be shared.** The lock check showed it is used only by
  gogmail. If `nix flake lock` changes any other node, that is a stop.
- **gogcli rebuild:** none. Only comments change in `pkgs/gogcli`, so the
  derivation is identical. This is verified by drvPath.
- **p510:** it evaluates only. It is built only with the owner's OK.

## Verification

1. `git grep -n -i gogmail -- ':!intent' ':!spec' ':!plan'` returns nothing.
2. `git diff origin/main -- flake.lock` removes exactly the four nodes, and
   no other node's `locked` changes.
3. `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
   succeeds for p620, razer and p510, with no new warnings.
4. The `gog` CLI `drvPath` is unchanged versus `origin/main` (p620 HM
   `programs.gogDashboard.package`).
5. `just test-host p620` builds. razer is built via p620 (`nix build` of its
   toplevel). p510 is eval only, unless the owner OKs a build.
6. The closure check: `nix path-info -r <p620 toplevel> | grep -i gogmail` is
   empty.
7. The built tmux config has no `M-c` and no `gogmail` line:
   `grep -n 'M-c\|gogmail'` on the generated `tmux.conf` and which-key
   files from the p620 HM generation.
