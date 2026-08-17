#!/usr/bin/env bash
# Pre-deploy guard for the EFI System Partition.
#
# Why this exists: on 2026-08-12 a razer deploy died half-way with
# "No space left on device" while Lanzaboote copied the initrd into /boot.
# The system had already been activated, so razer was RUNNING one generation
# while /boot could only boot an older one — a reboot away from a surprise.
#
# The trap is that the bootloader installs the NEW kernel+initrd *before* it
# garbage-collects the old ones, so the ESP must briefly hold
# configurationLimit + 1 generations. razer's initrds are ~150M (NVIDIA
# firmware) on a 511M ESP, so limit=3 needed 600M at peak and never fit.
#
# Usage:
#   check-boot-space.sh <host>            # host = local hostname or ssh target
#   check-boot-space.sh <host> --clean    # also reclaim space when low
#
# Exit 0 = enough room to deploy. Exit 1 = still short, deploy should abort.
set -euo pipefail

HOST="${1:?usage: check-boot-space.sh <host> [--clean]}"
CLEAN="${2:-}"

# Reserve room for one full generation plus slack. The bootloader needs to
# write a new kernel + initrd before pruning anything, and an ESP that is
# merely "not full" is not enough.
MIN_FREE_MIB=200

if [ "$HOST" = "$(hostname)" ] || [ "$HOST" = "local" ] || [ "$HOST" = "localhost" ]; then
  run() { bash -c "$1"; }
  LABEL="$(hostname) (local)"
else
  run() { ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOST" "$1"; }
  LABEL="$HOST"
fi

# shellcheck disable=SC2016  # single quotes are deliberate: `run` evaluates
# these remotely, so $4/$5 must reach the far side unexpanded.
free_mib() { run 'df -PBM /boot | awk "NR==2{gsub(/M/,\"\",\$4); print \$4}"'; }
# shellcheck disable=SC2016
used_pct() { run 'df -P /boot | awk "NR==2{gsub(/%/,\"\",\$5); print \$5}"'; }

FREE="$(free_mib)"
echo "🔎 ${LABEL}: /boot has ${FREE}MiB free ($(used_pct)% used), need ≥${MIN_FREE_MIB}MiB"

if [ "$FREE" -ge "$MIN_FREE_MIB" ]; then
  echo "✅ ${LABEL}: enough room on the ESP"
  exit 0
fi

if [ "$CLEAN" != "--clean" ]; then
  echo "❌ ${LABEL}: only ${FREE}MiB free — re-run with --clean, or the deploy will"
  echo "   fail half-way and leave the host running a generation it cannot boot."
  exit 1
fi

echo "🧹 ${LABEL}: reclaiming space…"

# 1. Partial copies left by a previous ENOSPC. Always orphans, never booted.
run 'sudo find /boot -name "*.tmp" -type f -print -delete 2>/dev/null || true'

# 2. Drop old system generations, then let the bootloader installer prune the
#    ESP entries that no longer belong to a generation. Deleting files out of
#    /boot by hand is how people brick a laptop: the installer knows which
#    kernel/initrd the remaining generations still reference, so let it decide.
#    +2 keeps the current generation and one fallback.
prune_to() {
  run "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +$1 2>/dev/null || true"
  run 'sudo /run/current-system/bin/switch-to-configuration boot 2>&1 | tail -3'
}

prune_to 2

FREE="$(free_mib)"
if [ "$FREE" -ge "$MIN_FREE_MIB" ]; then
  echo "✅ ${LABEL}: ${FREE}MiB free after cleanup"
  exit 0
fi

# Escalate to a single generation.
#
# Keeping 2 generations is not always reachable: on razer the initrds are
# ~150MiB, so 2 generations occupy 312MiB of a 511MiB ESP and leave 198MiB —
# permanently 2MiB under MIN_FREE_MIB. `--delete-generations +2` therefore
# "succeeded" while still failing the check, every single deploy.
#
# Dropping to 1 frees a full initrd. The fallback is not lost for long: the
# deploy that follows writes a second generation immediately, so the end state
# is still current + fallback. The window without a fallback lasts only until
# that switch completes, which beats refusing to deploy at all.
echo "🧹 ${LABEL}: ${FREE}MiB still short — escalating to a single generation"
prune_to 1

FREE="$(free_mib)"
if [ "$FREE" -ge "$MIN_FREE_MIB" ]; then
  echo "✅ ${LABEL}: ${FREE}MiB free after pruning to one generation"
  echo "   (the upcoming switch restores a second, so you keep a fallback)"
  exit 0
fi

echo "❌ ${LABEL}: still only ${FREE}MiB free after cleanup."
echo "   The ESP is too small for this host's initrd size, not just untidy."
echo "   Lower boot.loader.systemd-boot.configurationLimit for ${LABEL}, or"
echo "   grow the partition. Current ESP contents:"
run 'sudo ls -1sh /boot/EFI/nixos/ 2>/dev/null | head -20 || true'
exit 1
