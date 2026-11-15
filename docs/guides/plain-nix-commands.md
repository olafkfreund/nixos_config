# Plain nix commands

The Justfile keeps the recipes the daily workflow uses (#2950). One-off diagnostics that used to be recipes are
single `nix` commands; run them from the repo root. Replace `HOST` with `p620`, `razer` or `p510`.

`just --list` shows what is left, grouped as deploy, update, test, maintenance, secrets, lint and docs.

## Inspect a host's system

| Question | Command |
| --- | --- |
| Closure size of a host | `nix path-info -rsSh .#nixosConfigurations.HOST.config.system.build.toplevel \| tail -1` |
| Largest dependencies | `nix path-info -rsSh .#nixosConfigurations.HOST.config.system.build.toplevel \| sort -k2 -h \| tail -10` |
| What would be built | `nix build .#nixosConfigurations.HOST.config.system.build.toplevel --dry-run` |
| Derivation of a package | `nix derivation show nixpkgs#PACKAGE` |
| Value of an option | `nix eval .#nixosConfigurations.HOST.config.OPTION --show-trace` |
| Difference between two hosts | `nix store diff-closures $(nix build --no-link --print-out-paths .#nixosConfigurations.HOST1.config.system.build.toplevel) $(nix build --no-link --print-out-paths .#nixosConfigurations.HOST2.config.system.build.toplevel)` |

## Flake

| Question | Command |
| --- | --- |
| Outputs | `nix flake show` |
| Inputs and revisions | `nix flake metadata` |
| Update one input | `nix flake update INPUT` (then deploy with `nhs`) |
| Interactive evaluation | `nix repl` then `:lf .` |
| Evaluation time | `time nix eval .#nixosConfigurations.HOST.config.system.build.toplevel.drvPath` |

## The running system

| Question | Command |
| --- | --- |
| Generations | `nixos-rebuild list-generations` |
| What changed in the last switch | `nvd diff /run/booted-system /run/current-system` |
| Store garbage and optimisation | `just cleanup` (announce on the agent bus first) |

## Proving a refactor changes nothing

`scripts/config-snapshot.sh` records each host's revision-pinned system derivation and compares two trees. See
`scripts/README.md`.
