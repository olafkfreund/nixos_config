#!/usr/bin/env bash
# Does only_nvidia_units_failed() classify real activation output correctly?
#
# The matcher decides whether a failed `nh os switch` is downgraded to "stage
# for next boot and ask for a reboot" or left as a hard failure that rolls the
# host back. Getting it wrong in the permissive direction means a genuinely
# broken deploy is reported as success, so the interesting cases here are the
# ones it must REFUSE.
#
# The function is extracted from the deploy script rather than copied: a copy of
# a matcher in a test is a test of the copy.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update-commit-deploy.sh"
eval "$(sed -n '/^only_nvidia_units_failed() {/,/^}/p' "$src")"

fails=0
check() { # check <expect: yes|no> <description> <output text>
  local expect="$1" desc="$2" text="$3" f got
  f=$(mktemp)
  printf '%s\n' "$text" >"$f"
  if only_nvidia_units_failed "$f"; then got=yes; else got=no; fi
  rm -f "$f"
  if [ "$got" = "$expect" ]; then
    printf '  ok       %s\n' "$desc"
  else
    printf '  FAIL     %s (expected %s, got %s)\n' "$desc" "$expect" "$got"
    fails=$((fails + 1))
  fi
}

# The real p510 line, 2026-08-31, 595.91.07 loaded vs 595.99.02 wanted.
check yes "p510's three nvidia units" \
  'starting the following units: accounts-daemon.service, polkit.service
Failed to start nvidia-power-limit.service
warning: the following units failed: nvidia-container-toolkit-cdi-generator.service, nvidia-persistenced.service, nvidia-power-limit.service'

check yes "a single nvidia unit" \
  'warning: the following units failed: nvidia-persistenced.service'

# The one that matters: a real failure must not be waved through because a GPU
# unit happens to be in the list.
check no "nvidia plus something else" \
  'warning: the following units failed: nvidia-persistenced.service, home-assistant.service'

check no "no nvidia at all" \
  'warning: the following units failed: thermald.service'

check no "no failed-units line" \
  'activating the configuration...
the following new units were started: libvirtd.service'

# A rollback appends its own list; the switch attempt's is the last one written
# before the caller reacts, so tail -1 must win.
check no "rollback line last, mixed units" \
  'warning: the following units failed: nvidia-persistenced.service
warning: the following units failed: nvidia-persistenced.service, docker.service'

if [ "$fails" -ne 0 ]; then
  printf '\n%d case(s) failed\n' "$fails"
  exit 1
fi
printf '\nall cases passed\n'
