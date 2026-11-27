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
  installed into the disposable repository; each job attempt writes its own
  independent started/completed record (`0644`, named by run ID, attempt, runner,
  and PID) under `/var/lib/runner-drain-test/counters/` (`1777`).
- `run-test.py` — driver that ensures `workflow.yml` is installed on `main` of
  the disposable repository, builds and boots the VM, runs scenarios `(a)`
  through `(f)` against the real, unmodified `scripts/guarded_upgrade.py` with
  `GUARDED_*` environment overrides, and writes `recording.json`.
- `test_harness.py` — unit tests for repository/token resolution, `GUARDED_*`
  environment variable discovery against `scripts/guarded_upgrade.py`,
  per-attempt execution record aggregation, GitHub job transition tracking,
  boundary classification, and condition-skip collection.

## Running

```bash
export RUNNER_DRAIN_TEST_REPO="olafkfreund/<disposable-repo>"
export RUNNER_DRAIN_TEST_TOKEN_FILE="/path/to/disposable-token"
# or: export RUNNER_DRAIN_TEST_TOKEN="..."

python3 scripts/runner-drain-test/run-test.py \
  --output scripts/runner-drain-test/recording.json
```

## Scenarios covered

- **(a)** Synchronised on the broker side at the admission boundary: the offer
  acquired just before `drain/request` completes once before the switch, while
  the offer pending at the boundary stays queued across the switch and runs once
  after reopen.
- **(b)** A job dispatched after admission closes is verified `queued` on GitHub
  while the runners are closed, and runs once after the reopen.
- **(c)** The same as (b), with a forced verification failure in `candidate` and
  a real rollback to `baseline`.
- **(d)** One runner (`github-runner-nixarchy-4.service`) withholds its
  `drain/ack` in two ways (case 1: request hidden by a private mount; case 2:
  request visible, `drain/ack` path unwritable), and the switch defers both
  times.
- **(e)** The upgrade is interrupted by killing the Python PID itself at the
  actual state transitions (right after the `draining` journal phase is written
  before the marker, right after `/var/lib/guarded-upgrade/runners-closed` is
  written before requests while `scripts/deploy-hold.sh` refuses a manual deploy,
  and right after `settled-rollback` before reopen), and recovery reopens the
  runners every time.
- **(f)** One runner stays busy past the drain deadline, the drain defers without
  stopping the busy runner (`drain/ack` transitions to `cancelled`), and the
  in-flight job completes once.
