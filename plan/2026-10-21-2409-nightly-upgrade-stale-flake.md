---
status: draft
issue: 2409
spec: spec/2026-10-21-2409-nightly-upgrade-stale-flake.md
---

# Plan: nightly upgrade must not switch to a stale cached flake

## Approved decisions

- When `api.github.com` is unreachable, the nightly `nixos-upgrade.service`
  is skipped, not failed. A skipped night shows only in the journal, and the
  nightly timer tries again the next night.
- The mechanism is one systemd `ExecCondition` running curl with 5 retries
  30 s apart, at most about 4.5 minutes in total. The upstream `script` is not
  touched.
- Scope is `modules/nix/nix.nix` only, which affects p620 and razer. p510
  has autoUpgrade forced off, and the nixvm microvm is out of scope.
- If GitHub can be reached, behaviour is unchanged.

## Steps

1. `modules/nix/nix.nix:21`: insert this after the closing `};` of
   `system.autoUpgrade`:

   ```nix
   # A failed github: fetch falls back to a stale cached flake (#2409); skip the night instead.
   systemd.services.nixos-upgrade.serviceConfig.ExecCondition =
     "${pkgs.curl}/bin/curl -sfI -o /dev/null --max-time 20 --retry 5 --retry-delay 30 --retry-all-errors https://api.github.com";
   ```

   `pkgs` is already in the module's arguments.

   Verify by running:

   ```bash
   nix eval --raw .#nixosConfigurations.p620.config.systemd.services.nixos-upgrade.serviceConfig.ExecCondition
   ```

   It should print the curl command. Run the same for razer.

   Traps:
   - Edit in the `../nixos-2409` worktree, never in `~/.config/nixos`.
   - Keep the comment to one line (minimal comments).

2. Build by running `just test-host p620` and `just test-host razer`. Both
   should exit 0.
   Traps: pipe build output through `tail` only with `set -o pipefail` or
   `PIPESTATUS`.

3. Open a PR linking the intent, spec and plan, wait for CI to go green,
   then squash-merge.
   Traps:
   - Write the PR body to a file and pass it with `--body-file`. The bus guard
     matches prose words in commands.

4. Deploy p620 from main with `just p620`, after `read_new` and a `post` on
   `#agents:freundcloud.org.uk` and with `AGENT_BUS_ANNOUNCED=1` set. Then deploy
   razer with `just deploy-via-p620 razer`.
   Traps:
   - A p620 exit of rc=4 from `remote-fs.target` means the `/mnt/media`
     automount refused because it was already mounted. Fix it by stopping
     `mnt-media.mount` and starting `remote-fs.target`.

## Tests

On p620 after the deploy:

```bash
systemctl cat nixos-upgrade | grep ExecCondition
systemd-run --user --wait -q -u t2409 -p ExecCondition="$(command -v curl) -sfI -o /dev/null --max-time 5 https://api.github.invalid" true
journalctl --user -u t2409 -n 3 -o cat
```

- The first command shows the curl line.
- The `systemd-run` command exits 1.
- The journal reads "Skipped due to 'exec-condition'", which confirms that a
  failed probe skips the unit rather than failing it. This was checked on
  p620 on 2026-10-21.

Do not run `systemctl start nixos-upgrade` while online, because that
performs a real upgrade.

## Rollback

Revert the merge commit and deploy p620 and razer again. The upgrade then
runs without the condition, as it did before.
