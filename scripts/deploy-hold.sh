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
# lock must outlive any one ssh call and last the whole build and activation.
# - Each run names its own unit, so flock alone decides who holds the lock; a
#   run can never mistake another run's hold for its own.
# - While COMMAND runs, the hold is watched: if it ends (its RuntimeMaxSec, or
#   someone stopped it), COMMAND is stopped rather than left switching unguarded.
# - The hold is released on exit and on INT, TERM and HUP.
set -euo pipefail

host=${1:?usage: deploy-hold.sh HOST -- COMMAND...}
shift
[ "${1:-}" = -- ] && shift
[ $# -gt 0 ] || {
  echo "deploy-hold: no command" >&2
  exit 2
}

lock=/run/lock/nixos-deploy.lock
unit=deploy-hold-$(date +%s)-$$-$RANDOM
bin=/run/current-system/sw/bin # a transient unit's PATH does not have sleep in it

on_host() {
  if [ "$(hostname)" = "$host" ]; then
    bash -c "$1"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" "bash -c $(printf '%q' "$1")"
  fi
}
# 0 holding, 1 gone (inactive or no such unit), 2 cannot tell (host unreachable).
hold_state() {
  local rc=0
  on_host "systemctl is-active --quiet $unit" || rc=$?
  case $rc in
    0) return 0 ;;
    3 | 4) return 1 ;;
    *) return 2 ;;
  esac
}
holding() { hold_state; }

on_host "sudo systemd-run --quiet --unit=$unit --collect -p Type=exec -p RuntimeMaxSec=12h $bin/flock -n $lock $bin/sleep infinity" || {
  echo "deploy-hold: could not start a hold on $host" >&2
  exit 1
}
# flock -n exits at once when another holder has the lock, and --collect then
# removes the unit, so a unit of OUR name still running a moment later holds it.
sleep 2
if ! holding; then
  echo "deploy-hold: $host's deploy lock is held by its guarded upgrade or another deploy." >&2
  echo "  see: ssh $host systemctl list-units 'deploy-hold-*' nixos-upgrade.service" >&2
  exit 1
fi

child=
release() {
  trap - EXIT INT TERM HUP
  [ -n "$child" ] && kill "$child" 2>/dev/null || true
  # A hold that has already ended needs no release.
  on_host "sudo systemctl stop $unit 2>/dev/null || ! systemctl is-active --quiet $unit" \
    || echo "deploy-hold: could not release $unit on $host; run: ssh $host sudo systemctl stop $unit" >&2
}
trap release EXIT
trap 'release; exit 130' INT TERM HUP

"$@" &
child=$!
while kill -0 "$child" 2>/dev/null; do
  sleep 15
  kill -0 "$child" 2>/dev/null || break
  state=0
  hold_state || state=$?
  # Only a hold that is definitely gone stops the deploy: a switch often restarts
  # the network, and an unreachable host says nothing about the lock.
  if [ "$state" = 1 ]; then
    echo "deploy-hold: the hold on $host ended while the deploy was running; stopping it" >&2
    kill "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
    exit 1
  fi
done
rc=0
wait "$child" || rc=$?
child=
exit "$rc"
