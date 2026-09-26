---
status: draft
issue: 2044
intent: intent/2026-09-26-2044-coredump-cap-all-hosts.md
---

# Spec: every host caps its coredump storage

The intent was approved on 2026-09-26 without answers to its open questions,
so the recommended defaults are the decisions:

| # | Question | Decision |
| --- | --- | --- |
| 1 | Where the cap lives | (a) Every host gets it, with no gate |
| 2 | Deploy p510 in this task | **No.** "Continue" is not the explicit go-ahead p510 needs. p510 picks up the cap at its next routine deploy. This task only evaluates it |

**Correction to the intent's table:** p510 does **not** import
`logging.nix`. The only match in `hosts/p510/nixos/resilience.nix:179` is a
comment about a `daemon.settings` block that `logging.nix` no longer has. The
outcome is unchanged: p510 is uncapped.

## Design

All three hosts import `hosts/templates/desktop.nix`, which imports
`modules/core.nix` ("Core modules - always loaded on every host").

1. **`modules/system/logging.nix`:** the `systemd.coredump.settings.Coredump`
   block moves out of `mkIf cfg.enableFiltering`. The config becomes
   `lib.mkMerge [ { coredump } (mkIf cfg.enableFiltering { journald… }) ]`.
   The values stay `MaxUse = "1G"` and `KeepFree = "10G"`, and are wrapped in
   `lib.mkDefault` so a host can override them. The #1448 comment moves with
   the block, and gains one line saying the cap applies to every host, gate
   or not.
2. **`modules/core.nix`:** add `./system/logging.nix` to `imports`, next to
   `./system/fstrim-optimization.nix`.
3. **`hosts/p620/configuration.nix:44`:** drop its explicit
   `../../modules/system/logging.nix` import, since `core.nix` now provides
   it. `logging.enableFiltering = true` stays, so p620's journald filtering
   is unchanged.
4. **`hosts/p510/nixos/resilience.nix:179`:** delete the stale comment line
   "Merges with the daemon.settings block in modules/system/logging.nix".
   `logging.nix` no longer sets `daemon.settings` at all; its own comment
   says the Docker driver moved to `modules/containers/docker.nix`. The stale
   line sent this investigation the wrong way.

The option `system.logging.enableFiltering` is now declared on razer and
p510 too, but it stays `false` there. Their journald settings are untouched,
which was an intent constraint.

## Alternatives rejected

- **Turn on `enableFiltering` for razer and p510:** it brings in
  `MaxLevelStore=info`, rate limits and 7-day journal retention. The intent
  rules that out.
- **A new `modules/system/coredump.nix`:** it would be one more file for a
  four-line block that already lives next to its journald twin, with its
  history comment.
- **Per-host settings:** three copies of the same numbers, and a fourth host
  would miss it, which is the gap this task is closing.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| p620's `coredump.conf` or journald config changes by accident | p620 | T2: p620's `environment.etc."systemd/coredump.conf".text` and `services.journald` settings evaluate identically before and after |
| razer or p510 picks up journald filtering | razer, p510 | T3: their evaluated journald `Journal` settings match `origin/main` |
| Importing `logging.nix` twice (core plus a host) | any | Nix deduplicates imports by path. T1 builds all three hosts |
| The razer deploy collides with another agent | razer | Bus rule: read, announce, `AGENT_BUS_ANNOUNCED=1`. razer sees heavy agent traffic, so wait for no active claim |
| p510 stays uncapped until its next deploy | p510 | Accepted (decision 2). p510 had no cores on 2026-09-26 |

## Verification

1. **T1 build:** `just check-syntax`, then `just test-host p620` and
   `just test-host razer`. For p510, evaluate only:
   `nix eval .#nixosConfigurations.p510.config.environment.etc."systemd/coredump.conf".text`.
2. **T2, p620 unchanged:** evaluate p620's `coredump.conf` text and
   `services.journald.settings` on `origin/main` and on the branch, then
   `diff`. They must be identical.
3. **T3, the new hosts get only the cap:** on the branch, razer and p510's
   `coredump.conf` contains `MaxUse=1G` and `KeepFree=10G`, and their
   `services.journald.settings` matches `origin/main`.
4. **T4, live on razer:** after `just deploy-via-p620 razer`,
   `systemd-analyze cat-config systemd/coredump.conf` on razer shows both
   keys, and no units have failed.
5. **T5:** p510 is not deployed. Its evaluated value from T1 is recorded in
   the PR.
