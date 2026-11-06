#!/usr/bin/env bash
set -u

if [[ ${1-} == --run ]]; then
  pkg=$2 mode=$3 run=$4 run_dir=$5
  export HOME="$run_dir/home" XDG_DATA_HOME="$run_dir/data"
  export XDG_RUNTIME_DIR="$run_dir/runtime" XDG_CONFIG_HOME="$run_dir/config"
  mkdir -m 700 "$HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME"
  log="$run_dir/daemon.log"
  args=(sv plain s '')
  if [[ $mode == aes ]]; then
    args=(sv dh-ietf1024-sha256-aes128-cbc-pkcs7 ay 128)
    for ((i = 0; i < 128; i++)); do args+=(7); done
  fi

  # Disabling core files does not prevent aborts from reaching coredumpctl.
  ulimit -c 0
  "$pkg/bin/gnome-keyring-daemon" --foreground --components=secrets >"$log" 2>&1 &
  daemon_pid=$!
  trap 'kill "$daemon_pid" 2>/dev/null || :; wait "$daemon_pid" 2>/dev/null || :' EXIT

  ready=0 failed=0 aborted=0 reason=''
  for ((i = 0; i < 50; i++)); do
    if busctl --address="$DBUS_SESSION_BUS_ADDRESS" --no-pager --no-legend list 2>/dev/null \
      | awk '$1 == "org.freedesktop.secrets" { found = 1 } END { exit !found }'; then
      ready=1
      break
    fi
    kill -0 "$daemon_pid" 2>/dev/null || break
    sleep 0.1
  done

  if ((ready)); then
    reply=$(busctl --address="$DBUS_SESSION_BUS_ADDRESS" call \
      org.freedesktop.secrets /org/freedesktop/secrets \
      org.freedesktop.Secret.Service OpenSession "${args[@]}" 2>/dev/null)
    if [[ $? -ne 0 || $reply != *'/org/freedesktop/secrets/session/'* ]]; then
      failed=1
      reason='first waiting call failed'
    else
      for ((round = 0; round < 40; round++)); do
        kill -0 "$daemon_pid" 2>/dev/null || break
        pids=()
        for ((call = 0; call < 8; call++)); do
          busctl --address="$DBUS_SESSION_BUS_ADDRESS" --expect-reply=false call \
            org.freedesktop.secrets /org/freedesktop/secrets \
            org.freedesktop.Secret.Service OpenSession "${args[@]}" >/dev/null 2>&1 &
          pids+=("$!")
        done
        for pid in "${pids[@]}"; do wait "$pid" || :; done
      done
      if kill -0 "$daemon_pid" 2>/dev/null; then
        reply=$(busctl --address="$DBUS_SESSION_BUS_ADDRESS" call \
          org.freedesktop.secrets /org/freedesktop/secrets \
          org.freedesktop.Secret.Service OpenSession "${args[@]}" 2>/dev/null)
        if [[ $? -ne 0 || $reply != *'/org/freedesktop/secrets/session/'* ]]; then
          failed=1
          reason='final waiting call failed'
        fi
      fi
    fi
  else
    failed=1
    reason='bus name not acquired'
  fi

  if ! kill -0 "$daemon_pid" 2>/dev/null; then
    wait "$daemon_pid"
    status=$?
    if ((status == 134)); then
      aborted=1
    else
      failed=1
      reason="daemon exited with status $status"
    fi
  fi
  assertions=$(grep -c "assertion 'client' failed" "$log" || :)

  if ((aborted)); then
    printf 'run %d: aborted (assertions: %d)\n' "$run" "$assertions"
    exit 1
  elif ((failed)); then
    printf 'run %d: failed (%s; assertions: %d)\n' "$run" "$reason" "$assertions"
    exit 3
  elif ((assertions)); then
    printf 'run %d: survived, assertion fired (%d)\n' "$run" "$assertions"
    exit 0
  else
    printf 'run %d: survived, no assertion\n' "$run"
    exit 2
  fi
fi

if (($# < 1 || $# > 3)) || [[ ! -x $1/bin/gnome-keyring-daemon ]] \
  || [[ ${2:-plain} != plain && ${2:-plain} != aes ]] \
  || [[ ! ${3:-4} =~ ^[1-9][0-9]*$ ]]; then
  printf 'usage: %s <gnome-keyring store path> [plain|aes] [runs, default 4]\n' "$0" >&2
  exit 2
fi

pkg=$1 mode=${2:-plain} runs=${3:-4}
if ! command -v dbus-run-session >/dev/null; then
  printf 'dbus-run-session is unavailable\n' >&2
  exit 2
fi
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
aborts=0 failures=0 assertions=0
for ((run = 1; run <= runs; run++)); do
  run_dir="$root/$run"
  mkdir -m 700 "$run_dir"
  output=$(env -u DBUS_SESSION_BUS_ADDRESS dbus-run-session -- bash "$0" --run "$pkg" "$mode" "$run" "$run_dir")
  status=$?
  rm -rf "$run_dir"
  if [[ $output == run\ "$run":* ]]; then
    printf '%s\n' "$output"
  else
    printf 'run %d: failed (dbus-run-session exited with status %d)\n' "$run" "$status"
    ((failures += 1))
    continue
  fi
  case $status in
    0) ((assertions += 1)) ;;
    1) ((aborts += 1)) ;;
    2) ;; # one run missing the race proves nothing either way
    *) ((failures += 1)) ;;
  esac
done
printf 'summary: %d aborted, %d failed or inconclusive, %d survived with assertion\n' \
  "$aborts" "$failures" "$assertions"
if ((aborts)); then exit 1; fi
if ((failures || ! assertions)); then exit 2; fi
exit 0
