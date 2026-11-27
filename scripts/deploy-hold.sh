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
# - Refused while HOST's runner drain journal or closed marker exists (nixarchy#1967).
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

# Checked while holding the lock, so no drain can start afterwards. A check that
# fails refuses too.
for left in /var/lib/guarded-upgrade/{drain,runners-closed}; do
  if ! on_host "sudo test ! -e $left"; then
    echo "deploy-hold: $host has an unfinished runner drain, $left (or it could not be checked)." >&2
    echo "  its guarded upgrade recovers it: ssh $host sudo systemctl start nixos-upgrade.service" >&2
    echo "  if that keeps failing, journalctl -u nixos-upgrade.service names the runner. On $host, and only" >&2
    echo "  if /var/lib/guarded-upgrade/transaction does not exist (otherwise a switch is unfinished):" >&2
    echo "    1. remove a /var/lib/github-runner/<name>/drain that is a file or symlink," >&2
    echo "       or only the request file inside it when it is a directory;" >&2
    echo "    2. sudo rm -f /var/lib/guarded-upgrade/drain /var/lib/guarded-upgrade/runners-closed" >&2
    echo "    3. sudo systemctl start github-runner-nixarchy{,-2,-3,-4}.service" >&2
    exit 1
  fi
done

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
