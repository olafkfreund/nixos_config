---
status: approved
issue: 2044
spec: spec/2026-09-26-2044-coredump-cap-all-hosts.md
---

# Plan: every host caps its coredump storage

Branch `fix/2044-razer-coredump-cap`, in the worktree
`scratchpad/nixos-2044`, never the shared `~/.config/nixos` checkout.

## Approved decisions

These are carried over from the spec.

**D1. The cap is not gated.** In `modules/system/logging.nix`, the config
becomes:

```nix
config = lib.mkMerge [
  {
    # (the #1448 comment, plus one line: it applies to every host,
    # whether or not enableFiltering is set)
    systemd.coredump.settings.Coredump = {
      MaxUse = lib.mkDefault "1G";
      KeepFree = lib.mkDefault "10G";
    };
  }
  (mkIf cfg.enableFiltering {
    services.journald.settings.Journal = { … unchanged … };
  })
];
```

The Docker comment block stays where it is, inside the file.

**D2. Every host imports it.** `modules/core.nix` gets
`./system/logging.nix` next to `./system/fstrim-optimization.nix`.

**D3. The p620 import goes.** Line 44 of `hosts/p620/configuration.nix`
(`../../modules/system/logging.nix`) is removed. `logging.enableFiltering =
true` at line 555 stays.

**D4. The stale comment goes.** Line 179 of
`hosts/p510/nixos/resilience.nix` ("Merges with the daemon.settings block in
modules/system/logging.nix.") is removed, together with the blank `#` line
after it if that line is left orphaned.

**D5. p510 is not deployed.** It is evaluated only.

**Baselines,** captured on 2026-09-27 from this branch before any code
change (identical to origin/main for these values), in
`scratchpad/cd-baseline/`:

- p620 `coredump.conf`: `[Coredump]`, `KeepFree=10G`, `MaxUse=1G`
- razer and p510 `coredump.conf`: `[Coredump]` only
- `<host>-journald.json`: each host's `services.journald.settings`

## Steps

1. **Rebase** onto current `origin/main`.
   → verify: `git log origin/main..HEAD` shows only the #2044 docs commits.
2. **`modules/system/logging.nix`** (D1), **`modules/core.nix`** (D2),
   **`hosts/p620/configuration.nix`** (D3),
   **`hosts/p510/nixos/resilience.nix`** (D4).
   → verify: `just check-syntax` passes.
3. **Evaluate all three hosts** (T2, T3).
   → verify: they match the table below. If p620 differs in any way, stop.
4. **Build** p620 and razer (T1).
   → verify: both builds pass. Compare p620's toplevel with
   `/run/current-system`: the coredump and journald files must be
   identical. If they are, p620 needs no deploy for this change.
5. **Commit** as
   `fix(logging): cap coredump storage on every host (#2044)`, push, and
   open a PR that links the intent, spec and plan.
6. **Deploy razer:** read the bus and wait until nobody holds a razer claim,
   post a CLAIM, run `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`,
   then post "done" with the generation number.
   → verify: T4.
7. **Merge the PR**, once CI is green, with a squash that is pinned to the
   tested head (`--match-head-commit`).

## Deviations

- **Steps 6 and 7 are swapped (2026-09-28).** razer was user-reserved on the
  bus through the evening, and `main` moved twice meanwhile (razer is now on
  `ce3014c64`, generation 2957). Deploying the branch would have needed
  another rebase and rebuild first, and it is exactly the branch deploy
  #2052 is about to forbid. Instead: rebase onto `origin/main`, re-run T2
  and T3 (unchanged: p620, razer and p510 `coredump.conf` equal the
  verified values, and journald equals the baseline), merge on green CI, then
  deploy razer **from main** with `just deploy-via-p620 razer` from the shared
  checkout, bus-announced. T4 runs after that deploy.

## Tests

| # | Command | Expected |
| --- | --- | --- |
| T1 | `just check-syntax`; `just test-host p620`; `just test-host razer` | Pass |
| T2 | `nix eval --raw .#nixosConfigurations.p620.config.environment.etc."systemd/coredump.conf".text` and `nix eval --json …p620.config.services.journald.settings`, then `diff` each against its baseline | Identical |
| T3 | The same two evals for razer and p510, diffed against their baselines | `coredump.conf` gains exactly `KeepFree=10G` and `MaxUse=1G`; journald is identical |
| T4 | On razer: `systemd-analyze cat-config systemd/coredump.conf`; `systemctl --failed`; `systemctl --user --failed` | Both keys are present; 0 failed units |
| T5 | p510 is not deployed. Its T3 output goes in the PR description | Recorded |

## Rollback

- **Before merge:** close the PR. razer goes back to the previous
  generation with `sudo nixos-rebuild switch --rollback` on razer (announced
  on the bus).
- **After merge:** `git revert` the step-5 commit and redeploy razer. p620 is
  unaffected either way, because its values do not change.
