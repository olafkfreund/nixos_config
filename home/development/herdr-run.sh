#!/usr/bin/env bash
# Usage: herdr-run <codex|agy> <command> [args...]
# HERDR_RUN_TIME_SCALE scales waits for the isolated self-test (default: 1).
label=${1:?usage: herdr-run <codex|agy> <command> [args...]}
shift
if [[ $label != codex && $label != agy || $# -eq 0 ]]; then
  echo 'usage: herdr-run <codex|agy> <command> [args...]' >&2
  exit 2
fi
if [[ ${HERDR_ENV:-} != 1 || -z ${HERDR_SOCKET_PATH:-} || -z ${HERDR_TAB_ID:-} || -z ${HERDR_WORKSPACE_ID:-} ]]; then
  exec "$@"
fi

scale=${HERDR_RUN_TIME_SCALE:-1}
sleep_for() { sleep "$(awk -v n="$1" -v s="$scale" 'BEGIN { printf "%.3f", n*s }')"; }
h() { "${HERDR_BIN_PATH:-herdr}" "$@"; }
socket() { printf '%s\n' "$1" | socat -t5 - "UNIX-CONNECT:$HERDR_SOCKET_PATH"; }
same_pane() {
  local reply
  [[ -n ${pane:-} ]] || return 1
  reply=$(h pane get "$pane" 2>/dev/null) || return 1
  jq -e --arg terminal "$terminal" '.result.pane.terminal_id == $terminal' >/dev/null 2>&1 <<<"$reply"
}
close_pane() { if same_pane; then h pane close "$pane" >/dev/null 2>&1 || :; fi; }
report() { if same_pane; then h pane report-agent "$pane" --source herdr-run --agent "$label" --state "$1" >/dev/null 2>&1 || :; fi; }
release_pane() { if same_pane; then h pane release-agent "$pane" --source herdr-run --agent "$label" >/dev/null 2>&1 || :; fi; }
mark() { if same_pane; then h pane report-metadata "$pane" --source herdr-run --token "split_mark=↳ $label" >/dev/null 2>&1 || :; fi; }
kill_group() {
  local pgid
  [[ -f $dir/cmd.pgid ]] || return 1
  read -r pgid <"$dir/cmd.pgid" || return 1
  [[ $pgid =~ ^[0-9]+$ ]] && ((pgid > 1)) || return 1
  kill -"$1" -- "-$pgid" 2>/dev/null
}
# TERM the command's group, give it up to 5 s to go, then KILL what is left.
stop_group() {
  kill_group TERM || return 0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill_group 0 || return 0
    sleep_for 0.5
  done
  kill_group KILL || :
}
# Stop and reap every background job (marker, stdin feeder). jobs -p also
# covers a feeder whose PID was not recorded yet, and never names a reused PID.
stop_jobs() {
  local pids
  pids=$(jobs -p) || :
  [[ -n $pids ]] || return 0
  # shellcheck disable=SC2086 # one PID per word
  kill $pids 2>/dev/null || :
  wait 2>/dev/null || :
}
# shellcheck disable=SC2329 # EXIT trap
cleanup() {
  trap - EXIT
  stop_jobs
  rm -rf -- "$dir"
}
# shellcheck disable=SC2329 # signal traps
interrupt() {
  trap '' INT TERM HUP
  : >"$dir/cancel"
  if [[ -d $dir/claim ]]; then
    for _ in 1 2 3 4; do
      [[ -e $dir/cmd.pgid || -e $dir/status ]] && break
      sleep_for 0.5
    done
  fi
  stop_group
  close_pane
  exit "$1"
}
# Run the command here instead of in a pane. exec, so a signal sent to
# herdr-run reaches the command itself.
headless() {
  trap - INT TERM HUP EXIT
  # The feeder is still blocked opening the FIFO (no reader ever opened it),
  # so it has read nothing; it is reaped before the directory goes, so it
  # cannot recreate stdin as a file. The command gets the caller's stdin.
  stop_jobs
  rm -rf -- "$dir"
  exec "$@"
}
lost() {
  stop_group
  [[ -f $dir/out ]] && cat "$dir/out"
  [[ -f $dir/err ]] && cat "$dir/err" >&2
  echo "herdr-run: $label run lost (pane closed or runner died); not re-run" >&2
  close_pane
  exit 1
}

pane='' terminal='' tab=''
dir=$(mktemp -d) || exit 1
chmod 700 "$dir"
trap cleanup EXIT
trap 'interrupt 130' INT
trap 'interrupt 143' TERM
trap 'interrupt 129' HUP
# Stream stdin to the command through a FIFO; never read it up front. In
# Claude Code's Bash tool stdin is a socket that never sends EOF (#2679).
feeder_pid=
if [[ -t 0 ]]; then
  : >"$dir/stdin"
else
  mkfifo "$dir/stdin"
  # fd 3 is duplicated synchronously, so the async feeder surely reads the
  # caller's stdin; its stderr is closed so it never holds the caller's pipe.
  { (exec cat >"$dir/stdin" 2>/dev/null) <&3 3<&- & } 3<&0
  feeder_pid=$!
fi

# Only allow-listed names (agent-env.sh), one `declare -p` each so values with newlines survive.
while IFS= read -r -d '' name; do declare -p "$name"; done < <(agent_env_exported) >"$dir/env"
printf 'cwd=%q\n' "$PWD" >>"$dir/env"

title="$label review"
for arg in "$@"; do
  if [[ $arg == codex-implement || $arg == agy-implement ]]; then
    title="$label implement"
    break
  fi
done
{
  printf '#!/usr/bin/env bash\ncd %q || exit 127\n' "$dir"
  # the runner's own tools come from herdr-run's runtimeInputs, not the pane
  printf 'PATH=%q\n' "$PATH"
  printf 'cmd=('
  printf '%q ' "$@"
  printf ')\n'
  printf 'helper_pid=%q\nfeeder_pid=%q\nlabel=%q\ntitle=%q\nscale=%q\nherdr_bin=%q\n' "$$" "$feeder_pid" "$label" "$title" "$scale" "${HERDR_BIN_PATH:-herdr}"
  cat <<'RUNNER'
mkdir claim || exit 0
printf '%s\n' "$$" > runner.pid.tmp && mv runner.pid.tmp runner.pid
dir=$PWD pgid=
sleep_for() { sleep "$(awk -v n="$1" -v s="$scale" 'BEGIN { printf "%.3f", n*s }')"; }
same_pane() {
  local reply
  reply=$("$herdr_bin" pane get "$pane" 2>/dev/null) || return 1
  jq -e --arg terminal "$terminal" '.result.pane.terminal_id == $terminal' >/dev/null 2>&1 <<< "$reply"
}
close_pane() { if same_pane; then "$herdr_bin" pane close "$pane" >/dev/null 2>&1 || :; fi; }
# The group ID is held in memory once known, so it still works after the
# helper has removed the private directory.
kill_group() {
  local g=$pgid
  [[ -n $g ]] || read -r g < "$dir/cmd.pgid" 2>/dev/null || return 1
  [[ $g =~ ^[0-9]+$ ]] && (( g > 1 )) || return 1
  kill -"$1" -- "-$g" 2>/dev/null
}
stop_group() {
  kill_group TERM || return 0
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill_group 0 || return 0; sleep_for 0.5; done
  kill_group KILL
}
# With the helper gone nobody else stops its stdin feeder (it would block
# forever on a stdin that never closes). Only a process that is still a cat
# or a herdr-run copy is killed, so a reused PID is left alone.
kill_feeder() {
  [[ -n ${feeder_pid:-} ]] || return 0
  grep -qa -E 'cat|herdr-run' "/proc/$feeder_pid/cmdline" 2>/dev/null || return 0
  kill "$feeder_pid" 2>/dev/null
}
finish() {
  trap - EXIT
  trap '' HUP INT TERM
  helper_alive=1
  kill -0 "$helper_pid" 2>/dev/null || helper_alive=
  # stopped early (pane closed, signal) or orphaned: stop the whole group before anything else
  if [[ ! -e $dir/status || -z $helper_alive ]]; then stop_group; fi
  if [[ ! -e $dir/status ]]; then printf 'lost\n' > "$dir/status.tmp" && mv "$dir/status.tmp" "$dir/status"; fi
  if [[ -n ${watchdog_pid:-} ]]; then kill "$watchdog_pid" 2>/dev/null; fi
  # with the helper gone nobody else cleans up
  if [[ -z $helper_alive ]]; then kill_feeder; rm -rf -- "$dir"; close_pane; fi
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
printf '\033]0;%s\007' "$title"
: > out; : > err
# $0 is the private directory: the command runs in the caller's cwd.
setsid -w env -i "$BASH" --noprofile --norc -c \
  'source "$0/env" && cd "$cwd" && [ ! -e "$0/cancel" ] &&
   echo $$ > "$0/cmd.pgid.tmp" && mv "$0/cmd.pgid.tmp" "$0/cmd.pgid" &&
   exec "$@"; exit 127' "$PWD" "${cmd[@]}" < stdin > out 2> err &
cpid=$!
for _ in $(seq 100); do
  [[ -f cmd.pgid ]] && break
  kill -0 "$cpid" 2>/dev/null || break
  sleep 0.05
done
read -r pgid < cmd.pgid 2>/dev/null || pgid=
(
  while sleep_for 2; do
    if ! kill -0 "$helper_pid" 2>/dev/null; then
      # cpid may still be blocked opening stdin (no group yet), so end it too
      stop_group; kill_feeder; kill "$cpid" 2>/dev/null; exit 0
    fi
  done
) &
watchdog_pid=$!
tail --pid="$cpid" -f out err &
wait "$cpid"; code=$?
printf '%s\n' "$code" > status.tmp && mv status.tmp status
exit "$code"
RUNNER
} >"$dir/run"
chmod 700 "$dir/run"

# Put the new tab right after the lead and any child tabs already there.
# Cosmetic: called as `place_tab || :`, so no failure in here stops the run.
place_tab() {
  local tabs panes ids insert i child child_reply
  tabs=$(socket "$(jq -nc --arg w "$HERDR_WORKSPACE_ID" '{id:"1",method:"tab.list",params:{workspace_id:$w}}')" 2>/dev/null) || return 0
  panes=$(socket "$(jq -nc --arg w "$HERDR_WORKSPACE_ID" '{id:"1",method:"pane.list",params:{workspace_id:$w}}')" 2>/dev/null) || return 0
  # leave out our own tab: it is already marked, and would count as a child
  mapfile -t ids < <(jq -r --arg own "$tab" '.result.tabs[]?.tab_id | select(. != $own)' <<<"$tabs" 2>/dev/null)
  insert=-1
  for i in "${!ids[@]}"; do
    if [[ ${ids[i]} == "$HERDR_TAB_ID" ]]; then
      insert=$((i + 1))
      break
    fi
  done
  ((insert >= 0)) || return 0
  while ((insert < ${#ids[@]})); do
    child=$(jq -r --arg tab "${ids[insert]}" 'first(.result.panes[]? | select(.tab_id == $tab) | .pane_id) // empty' <<<"$panes" 2>/dev/null) || break
    [[ -n $child ]] || break
    child_reply=$(h pane get "$child" 2>/dev/null) || break
    jq -e '.result.pane.tokens.split_mark != null' >/dev/null 2>&1 <<<"$child_reply" || break
    insert=$((insert + 1))
  done
  socket "$(jq -nc --arg tab "$tab" --argjson n "$insert" '{id:"1",method:"tab.move",params:{tab_id:$tab,insert_index:$n}}')" >/dev/null 2>&1 || :
}

lock="${XDG_RUNTIME_DIR:-/tmp}/herdr-run-${HERDR_TAB_ID}.lock"
exec {lock_fd}>"$lock"
flock "$lock_fd"
created=$(h tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "↳ $label" --no-focus 2>/dev/null) || created=
pane=$(jq -r '.result.root_pane.pane_id // empty' 2>/dev/null <<<"$created") || pane=
terminal=$(jq -r '.result.root_pane.terminal_id // empty' 2>/dev/null <<<"$created") || terminal=
tab=$(jq -r '.result.tab.tab_id // empty' 2>/dev/null <<<"$created") || tab=
if [[ -z $pane || -z $terminal || -z $tab ]]; then
  flock -u "$lock_fd"
  close_pane
  headless "$@"
fi
# Bake the returned identity ahead of the runner body.
{
  printf 'pane=%q\nterminal=%q\n' "$pane" "$terminal"
  cat "$dir/run"
} >"$dir/run.tmp"
mv "$dir/run.tmp" "$dir/run"
mark
place_tab || :
flock -u "$lock_fd"

for ((attempt = 1; attempt <= 3; attempt++)); do
  if ! h pane run "$pane" "bash $(printf '%q' "$dir/run")" >/dev/null 2>&1; then break; fi
  for _ in 1 2; do
    [[ -d $dir/claim ]] && break 2
    sleep_for 0.5
  done
done
if [[ ! -d $dir/claim ]]; then
  if mkdir "$dir/claim" 2>/dev/null; then
    close_pane
    headless "$@"
  fi
  for _ in 1 2; do
    [[ -f $dir/runner.pid ]] && break
    sleep_for 0.5
  done
fi
report working
(
  sleep_for 2
  mark
  sleep_for 4
  mark
  sleep_for 9
  mark
) &

# Wait in 1 s steps so a signal is handled promptly. Every 5 s check that the
# pane and runner still exist; two misses in a row mean the run is lost.
ticks=0 misses=0
while [[ ! -f $dir/status ]]; do
  sleep_for 1
  ticks=$((ticks + 1))
  ((ticks % 5 == 0)) || continue
  [[ ! -f $dir/status ]] || break
  if same_pane && [[ -f $dir/runner.pid ]] && kill -0 "$(cat "$dir/runner.pid")" 2>/dev/null; then
    misses=0
    continue
  fi
  [[ ! -f $dir/status ]] || break
  misses=$((misses + 1))
  ((misses < 2)) || lost
done
read -r code <"$dir/status" || code=
[[ $code =~ ^[0-9]+$ ]] || lost
cat "$dir/out"
cat "$dir/err" >&2
report idle
sleep_for 3
release_pane
close_pane
exit "$code"
