---
status: approved
issue: 2409
intent: intent/2026-10-21-2409-nightly-upgrade-stale-flake.md
---

# Spec: nightly upgrade must not switch to a stale cached flake

The intent's open questions are settled with its stated defaults: a
skipped night is recorded in the journal only, and the nixvm microvm is out
of scope.

## Design

Add one systemd `ExecCondition` to the upstream unit in
`modules/nix/nix.nix`, next to the existing `system.autoUpgrade` block:

```nix
systemd.services.nixos-upgrade.serviceConfig.ExecCondition =
  "${pkgs.curl}/bin/curl -sfI -o /dev/null --max-time 20 --retry 5 --retry-delay 30 --retry-all-errors https://api.github.com";
```

The design rests on three facts:

- The upstream unit (`nixos/modules/tasks/auto-upgrade.nix`) is a oneshot
  with `script` and no `ExecCondition`. Adding the condition does not
  conflict with anything upstream, and the script stays untouched.
- When an `ExecCondition` command exits with a code from 1 to 254, systemd
  skips the unit without marking it failed. The journal records "Condition
  check resulted in NixOS Upgrade being skipped" together with curl's error.
  The nightly timer stays armed, so the next night tries again. This meets
  the constraint that a network outage must not leave a failed unit.
- The `github:` fetcher resolves the flake's revision through
  `api.github.com`, and that is the step that fell back to the cache on
  2026-10-21. Probing that same host tests the actual failure point. The
  retries (5 × 30 s, at most about 4.5 minutes in total) mean a brief network
  hiccup still lets the night's upgrade run instead of skipping it.

When GitHub is reachable, the condition passes after one request and the
unit runs exactly as it does today.

## Alternatives rejected

- **A `preStart` check that exits non-zero.** It marks the unit as failed,
  which breaks the intent's constraint. A failed `nixos-upgrade` then shows
  up in every later `systemctl --failed` and in deploy checks.
- **Wrapping or replacing the upstream `script`.** It is a larger diff, and it
  forks behaviour that upstream maintains, including the reboot-window logic.
- **A Nix setting that refuses the cached fallback.** No such setting
  exists for the `github:` fetcher. `--refresh` is already passed and is
  exactly what falls back.
- **Removing `--refresh`, or pinning a local path such as `/etc/nixos`.**
  That changes what gets deployed: a local path builds whatever the shared
  checkout has checked out, which is a known trap in this repo.
- **Comparing the evaluated revision with main after the build.** It needs
  network access for the same comparison and adds much more code than the
  probe.

## Risks

- **A race between the probe and the fetch.** GitHub could answer the probe
  and then fail during the fetch a few seconds later. The window is tiny,
  and the 2026-10-21 outage lasted far longer. This is accepted.
- **Rate limits.** Unauthenticated `api.github.com` allows 60 requests per
  hour per IP, and the check makes one to six requests per host per night.
- **Proxy settings.** The unit's environment already carries
  `networking.proxy.envVars`, which curl honours, so the probe and the fetch
  take the same network path.
- **Hosts affected.** p620 and razer only. p510 has autoUpgrade forced off,
  and the condition is set inside the module whose upgrade is disabled there.
  The unit definition simply carries an unused condition.

## Verification

- `nix eval` of
  `nixosConfigurations.{p620,razer}.config.systemd.services.nixos-upgrade.serviceConfig.ExecCondition`
  returns the curl command.
- `just test-host p620` and `just test-host razer` build.
- After the deploy to p620:
  - `systemctl cat nixos-upgrade` shows the `ExecCondition` line.
  - To test the skip without the upgrade itself, run the probe command with
    an unresolvable URL, such as `https://api.github.invalid`, and confirm it
    exits non-zero. Then run `systemd-run --wait -p ExecCondition=...false`
    against a no-op unit to confirm that systemd reports "skipped", not
    "failed".
  - Do not start `nixos-upgrade` by hand while online: that would perform a
    real upgrade.
