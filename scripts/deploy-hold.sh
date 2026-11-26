#!/usr/bin/env bash
# deploy-hold.sh HOST -- COMMAND...
#
# Run a manual deploy while holding HOST's deploy lock, the same lock the guarded
# upgrade (scripts/guarded_upgrade.py) takes, so the two can never switch HOST at
# once (nixarchy#1946). The lock lives on the TARGET: a remote deploy runs on
# another machine and is invisible to the target until it activates, so only a
# lock on the target can exclude it.
#
# The hold is a transient unit on HOST running `flock -n LOCK sleep`, because the
# lock must outlive this ssh call and survive the whole build and activation. It
# is released on exit, success or not; RuntimeMaxSec bounds a hold a crash left.
set -euo pipefail

host=${1:?usage: deploy-hold.sh HOST -- COMMAND...}
shift
[ "${1:-}" = -- ] && shift
[ $# -gt 0 ] || {
  echo "deploy-hold: no command" >&2
  exit 2
}

lock=/run/lock/nixos-deploy.lock
unit=deploy-hold

on_host() {
  if [ "$(hostname)" = "$host" ]; then bash -c "$1"; else ssh -o BatchMode=yes "$host" "bash -c $(printf '%q' "$1")"; fi
}

if on_host "systemctl is-active --quiet $unit"; then
  echo "deploy-hold: $host already has a deploy hold; if no deploy is running: ssh $host sudo systemctl stop $unit" >&2
  exit 1
fi
# Absolute paths: a transient unit's PATH does not have sleep in it.
bin=/run/current-system/sw/bin
on_host "sudo systemd-run --quiet --unit=$unit --collect -p Type=exec -p RuntimeMaxSec=6h $bin/flock -n $lock $bin/sleep 21600" \
  || {
    echo "deploy-hold: could not start the hold on $host" >&2
    exit 1
  }
# flock -n exits at once when the guarded upgrade holds the lock, so a hold that
# is still running a moment later is a hold that has the lock.
sleep 2
if ! on_host "systemctl is-active --quiet $unit"; then
  echo "deploy-hold: $host's deploy lock is held, most likely by its guarded upgrade; try again when nixos-upgrade.service finishes" >&2
  exit 1
fi
release() { on_host "sudo systemctl stop $unit" || echo "deploy-hold: could not release the hold on $host; ssh $host sudo systemctl stop $unit" >&2; }
trap release EXIT

"$@"
