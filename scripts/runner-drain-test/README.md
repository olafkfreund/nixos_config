# Runner drain disposable VM test harness (`nixarchy#1967`)

End-to-end QEMU VM test harness for `pkgs/github-runner-drain`,
`modules/services/nixarchy-runner.nix`, and `scripts/guarded_upgrade.py`.

## Layout

- `vm.nix` — isolated two-generation NixOS QEMU VM configuration (`baseline` and
  `candidate`), with outbound network access, `modules/services/nixarchy-runner.nix`
  configured for 4 runners under a unique label against the disposable repository,
  and `runner-drain-candidate-check.service` in `candidate` (which fails
  verification when `/etc/runner-drain-test/force-verify-fail` is present).
- `workflow.yml` — GitHub Actions workflow (`.github/workflows/drain-test.yml`)
  installed into the disposable repository; each job run atomically updates
  started/completed execution counters and event logs under
  `/var/lib/runner-drain-test/counters/`.
- `run-test.py` — driver that ensures `workflow.yml` is installed on `main` of
  the disposable repository, builds and boots the VM, runs scenarios `(a)`
  through `(f)` against the real `scripts/guarded_upgrade.py` with environment
  overrides, and writes `recording.json`.
- `test_harness.py` — unit tests for repository/token resolution, AST-based
  environment variable discovery against `scripts/guarded_upgrade.py`, and
  condition-skip collection.

## Running

```bash
export RUNNER_DRAIN_TEST_REPO="olafkfreund/<disposable-repo>"
export RUNNER_DRAIN_TEST_TOKEN_FILE="/path/to/disposable-token"
# or: export RUNNER_DRAIN_TEST_TOKEN="..."

python3 scripts/runner-drain-test/run-test.py \
  --output scripts/runner-drain-test/recording.json
```

## Scenarios covered

- **(a)** A job acquired at the admission boundary completes exactly once, before
  the system switch.
- **(b)** A job dispatched after admission closes queues while the runners are
  closed, and runs exactly once after the reopen.
- **(c)** The same as (b), with a forced verification failure in `candidate` and
  a real rollback to `baseline`.
- **(d)** One runner (`github-runner-nixarchy-4.service`) withholds its
  `drain/ack`, and the switch defers without stopping or restarting that runner.
- **(e)** The upgrade is interrupted right after `/var/lib/guarded-upgrade/runners-closed`
  is written (while `scripts/deploy-hold.sh` refuses a manual deploy), then again
  right after a rollback (`settled-rollback`), and recovery reopens the runners
  both times.
- **(f)** One runner stays busy past the drain deadline, the drain defers without
  stopping the busy runner (`drain/ack` transitions to `cancelled`), and the
  in-flight job completes once.
