#!/usr/bin/env bash
# system-diff.sh [HOST] [OLD NEW]
#
# Show what a NixOS switch changed — Added / Removed / Upgraded packages —
# between two system generations, using nvd. This is the "what was installed,
# updated and deleted" view that `nh os switch` only shows partially (nh's
# --diff is version-level only, and it skips the diff entirely on remote
# --target-host deploys). Run it any time to inspect the last update.
#
# Usage:
#   system-diff.sh                # local: the two most recent generations
#                                 # (i.e. what the last `nhs`/rebuild changed)
#   system-diff.sh razer          # remote HOST over SSH: its two most recent
#   system-diff.sh razer 40 41    # remote HOST: explicit generation numbers
#   system-diff.sh - 2250 2251    # local, explicit generations ('-' = local)
#
# No sudo needed: generation symlinks under /nix/var/nix/profiles are readable,
# and nvd ships in every host's system closure.
set -euo pipefail

host="local"
remote=0
if [ "${1:-}" ] && [ "$1" != "-" ] && ! [[ "$1" =~ ^[0-9]+$ ]]; then
  host="$1"
  remote=1
  shift
elif [ "${1:-}" = "-" ]; then
  shift
fi

# Run a single shell-command string locally or on $host (one arg to ssh — no
# arg-flattening surprises).
sh_run() {
  if [ "$remote" -eq 1 ]; then
    ssh "$host" "$1"
  else
    bash -c "$1"
  fi
}

if ! sh_run 'command -v nvd >/dev/null 2>&1'; then
  echo "error: nvd not found on ${host}" >&2
  exit 1
fi

if [ "$#" -ge 2 ]; then
  old_n="$1"
  new_n="$2"
else
  mapfile -t gens < <(sh_run 'ls -d /nix/var/nix/profiles/system-*-link 2>/dev/null | sed -E "s#.*/system-([0-9]+)-link#\1#" | sort -n')
  if [ "${#gens[@]}" -lt 2 ]; then
    echo "error: need at least 2 system generations on ${host} (found ${#gens[@]})" >&2
    exit 1
  fi
  old_n="${gens[-2]}"
  new_n="${gens[-1]}"
fi

old="/nix/var/nix/profiles/system-${old_n}-link"
new="/nix/var/nix/profiles/system-${new_n}-link"

printf '\033[1;34m>> %s: package changes  gen %s -> %s\033[0m\n' "$host" "$old_n" "$new_n"
sh_run "nvd diff '$old' '$new'"
