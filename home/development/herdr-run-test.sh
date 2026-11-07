#!/usr/bin/env bash
# shellcheck disable=SC2016 # The quoted strings are passed to child shells.
# Clear the live pane's connection before creating any test state or subprocess.
while IFS= read -r name; do unset "$name"; done < <(compgen -A variable HERDR_)
set -euo pipefail
tool=${1:?usage: herdr-run-test.sh <herdr-run>}
tmp=$(mktemp -d)
trap 'kill "${socket_pid:-}" 2>/dev/null || :; rm -rf "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp/runtime" TEST_STATE="$tmp/state" HERDR_BIN_PATH="$tmp/fake-herdr" TMPDIR="$tmp"
mkdir -p "$XDG_RUNTIME_DIR" "$TEST_STATE"
export HERDR_ENV=1 HERDR_TAB_ID=lead HERDR_WORKSPACE_ID=workspace
export HERDR_SOCKET_PATH="$tmp/socket" HERDR_RUN_TIME_SCALE=0.05
cat >"$HERDR_BIN_PATH" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TEST_STATE/log"
[[ ! -e $TEST_STATE/fail-$1-$2 ]] || exit 1
case "$1 $2" in
  'tab create')
    ( flock 9
      n=$(cat "$TEST_STATE/n"); n=$((n+1)); printf '%s\n' "$n" > "$TEST_STATE/n"
      printf '%s\n' "$n" >> "$TEST_STATE/tabs"
      jq -nc --arg id "$n" '{result:{root_pane:{pane_id:("p"+$id),terminal_id:("t"+$id)},tab:{tab_id:$id}}}'
    ) 9> "$TEST_STATE/state.lock"
    ;;
  'pane get')
    [[ ! -e $TEST_STATE/vanish ]] || exit 1
    id=${3#p}
    terminal="t$id"
    [[ ! -e $TEST_STATE/change-id ]] || terminal=changed
    marked=false
    [[ ! -e $TEST_STATE/mark-$id ]] || marked=true
    jq -nc --arg terminal "$terminal" --argjson marked "$marked" '{result:{pane:{terminal_id:$terminal,tokens:(if $marked then {split_mark:"child"} else {} end)}}}'
    ;;
  'pane run')
    if [[ -e $TEST_STATE/drop-first && ! -e $TEST_STATE/dropped ]]; then : > "$TEST_STATE/dropped"; exit 0; fi
    if [[ -e $TEST_STATE/no-claim ]]; then printf '%s\n' "$4" > "$TEST_STATE/late-line"; exit 0; fi
    nohup bash -c "$4" >/dev/null 2>&1 </dev/null &
    ;;
  'pane report-metadata')
    id=${3#p}; : > "$TEST_STATE/mark-$id"
    ;;
  'pane close') : > "$TEST_STATE/closed" ;;
  'pane report-agent'|'pane release-agent') : ;;
  *) exit 2 ;;
esac
FAKE
cat >"$tmp/socket-server" <<'SOCKET'
#!/usr/bin/env bash
IFS= read -r request || exit 1
[[ ! -e $TEST_STATE/socket-error || $request != *pane.list* ]] || { printf '{"id":"1","error":{"code":"boom","message":"x"}}\n'; exit 0; }
method=$(jq -r '.method' <<< "$request")
case $method in
  tab.list)
    jq -Rn '[inputs | select(length>0) | {tab_id:.}] | {result:{tabs:.}}' < "$TEST_STATE/tabs"
    ;;
  pane.list)
    jq -Rn '[inputs | select(length>0) | select(. != "lead") | {pane_id:("p"+.),tab_id:.}] | {result:{panes:.}}' < "$TEST_STATE/tabs"
    ;;
  tab.move)
    tab=$(jq -r '.params.tab_id' <<< "$request")
    index=$(jq -r '.params.insert_index' <<< "$request")
    printf '%s %s\n' "$tab" "$index" >> "$TEST_STATE/moves"
    ;;
  *) exit 2 ;;
esac
SOCKET
# The Nix build sandbox has no /usr/bin/env: point the fakes at this bash.
sed -i "1s|.*|#!$(command -v bash)|" "$HERDR_BIN_PATH" "$tmp/socket-server"
chmod +x "$HERDR_BIN_PATH" "$tmp/socket-server"
socat UNIX-LISTEN:"$HERDR_SOCKET_PATH",fork EXEC:"$tmp/socket-server" &
socket_pid=$!
for _ in {1..50}; do
  [[ -S $HERDR_SOCKET_PATH ]] && break
  sleep 0.02
done
[[ -S $HERDR_SOCKET_PATH ]]

reset_state() {
  find "$TEST_STATE" -mindepth 1 -maxdepth 1 -type f -delete
  printf '0\n' >"$TEST_STATE/n"
  printf 'lead\n' >"$TEST_STATE/tabs"
}
run_capture() {
  code=0
  "$tool" codex "$@" >"$tmp/out" 2>"$tmp/err" || code=$?
}
ok() { printf 'ok %s\n' "$1"; }
assert_code() { [[ $code == "$1" ]] || {
  printf 'expected %s, got %s\n' "$1" "$code" >&2
  exit 1
}; }
assert_bytes() { cmp -s "$tmp/out" "$tmp/want-out" && cmp -s "$tmp/err" "$tmp/want-err"; }
count_runs() { [[ $(wc -l <"$TEST_STATE/runs") == "$1" ]]; }

reset_state
printf 'prompt\0bytes\n' >"$tmp/input"
printf 'stdout\0bytes\n' >"$tmp/want-out"
printf 'stderr\0bytes\n' >"$tmp/want-err"
for expected in 0 3 124; do
  code=0
  HERDR_ENV=0 "$tool" codex bash -c 'cat; printf "stderr\0bytes\n" >&2; exit "$1"' _ "$expected" <"$tmp/input" >"$tmp/out" 2>"$tmp/err" || code=$?
  assert_code "$expected"
  printf 'prompt\0bytes\n' >"$tmp/want-out"
  assert_bytes
done
ok outside-herdr

reset_state
for expected in 0 3 124; do
  run_capture bash -c 'cat; printf "stderr\0bytes\n" >&2; exit "$1"' _ "$expected" <"$tmp/input"
  assert_code "$expected"
  assert_bytes
done
ok pane-io

reset_state
: >"$TEST_STATE/fail-tab-create"
run_capture bash -c 'printf "x\n" >> "$TMPDIR/state/runs"'
assert_code 0
count_runs 1
ok create-fails

reset_state
: >"$TEST_STATE/no-claim"
"$tool" codex bash -c 'printf "x\n" >> "$TMPDIR/state/runs"; sleep 0.3' >"$tmp/out" 2>"$tmp/err" &
job=$!
for _ in {1..100}; do
  claim=$(find "$TMPDIR" -name claim -type d -print -quit)
  [[ -n $claim ]] && break
  sleep 0.01
done
[[ -n $claim ]]
# the late runner finds the claim taken, or its directory already gone: either way it runs nothing
bash -c "$(cat "$TEST_STATE/late-line")" >/dev/null 2>&1 || :
code=0
wait "$job" || code=$?
assert_code 0
count_runs 1
ok claim-race

reset_state
"$tool" codex bash -c 'printf "partial\n"; printf "x\n" >> "$TMPDIR/state/runs"; sleep 2' >"$tmp/out" 2>"$tmp/err" &
job=$!
for _ in {1..100}; do
  [[ -e $TEST_STATE/runs ]] && break
  sleep 0.01
done
: >"$TEST_STATE/vanish"
code=0
wait "$job" || code=$?
assert_code 1
grep -qF partial "$tmp/out"
grep -qF 'run lost (pane closed or runner died); not re-run' "$tmp/err"
count_runs 1
ok pane-vanishes

reset_state
"$tool" codex bash -c 'printf "x\n" >> "$TMPDIR/state/runs"; sleep 2' >"$tmp/out" 2>"$tmp/err" &
job=$!
for _ in {1..100}; do
  runner=$(find "$TMPDIR" -name runner.pid -path '*/tmp.*/*' -print -quit 2>/dev/null || :)
  [[ -n $runner ]] && break
  sleep 0.01
done
# The helper stores its private directory under TMPDIR for this case.
if [[ -n $runner ]]; then kill "$(cat "$runner")" 2>/dev/null || :; fi
code=0
wait "$job" || code=$?
[[ $code == 1 || $code == 127 ]]
ok runner-dies

reset_state
: >"$TEST_STATE/drop-first"
run_capture bash -c 'printf "x\n" >> "$TMPDIR/state/runs"'
assert_code 0
count_runs 1
ok resend

reset_state
script -qec "$(printf '%q ' "$tool" codex bash -c '[[ $(cat) == "" ]]')" /dev/null </dev/null >"$tmp/script-out" 2>"$tmp/script-err"
ok terminal-stdin

reset_state
: >"$TEST_STATE/fail-pane-run"
printf 'full prompt\nsecond line\n' >"$tmp/input"
run_capture cat <"$tmp/input"
assert_code 0
cmp -s "$tmp/input" "$tmp/out"
ok saved-stdin-fallback

reset_state
: >"$TEST_STATE/change-id"
run_capture true
assert_code 0
if grep -Eq '^pane (close|report-agent|release-agent)' "$TEST_STATE/log"; then exit 1; fi
ok changed-terminal-id

reset_state
# A background job starts with SIGINT ignored, which a shell cannot trap; restore it.
script -qec "$(printf '%q ' env --default-signal=INT "$tool" codex bash -c 'echo $$ > "$TMPDIR/state/command-pid"; exec sleep 300')" /dev/null >"$tmp/out" 2>"$tmp/err" &
script_pid=$!
for _ in {1..100}; do
  [[ -e $TEST_STATE/command-pid ]] && break
  sleep 0.01
done
runfile=$(find "$TMPDIR" -name run -type f -print -quit)
helper=$(sed -n 's/^helper_pid=//p' "$runfile")
kill -INT "$helper"
code=0
wait "$script_pid" || code=$?
assert_code 130
if kill -0 "$(cat "$TEST_STATE/command-pid")" 2>/dev/null; then exit 1; fi
ok ctrl-c

reset_state
"$tool" codex bash -c 'sleep 0.4' >"$tmp/out1" 2>"$tmp/err1" &
first=$!
for _ in {1..100}; do
  [[ -e $TEST_STATE/mark-1 ]] && break
  sleep 0.01
done
"$tool" agy bash -c 'sleep 0.1' >"$tmp/out2" 2>"$tmp/err2" &
second=$!
wait "$first"
wait "$second"
grep -qF "2 2" "$TEST_STATE/moves" || {
  echo "moves:"
  cat "$TEST_STATE/moves"
  echo "log:"
  grep -E "tab create|pane get" "$TEST_STATE/log"
  exit 1
}
ok parallel-position

# kill -9 of the helper: the watchdog stops the command, and the pane still closes
reset_state
"$tool" codex bash -c 'echo $$ > "$TMPDIR/state/command-pid"; exec sleep 300' >/dev/null 2>&1 &
helper=$!
for _ in {1..300}; do
  [[ -e $TEST_STATE/command-pid ]] && break
  sleep 0.01
done
kill -KILL "$helper"
wait "$helper" 2>/dev/null || :
for _ in {1..200}; do
  [[ -e $TEST_STATE/closed ]] && break
  sleep 0.02
done
[[ -e $TEST_STATE/closed ]]
if kill -0 "$(cat "$TEST_STATE/command-pid")" 2>/dev/null; then exit 1; fi
ok helper-killed

# the runner is signalled (its tab closed): the command group stops, the helper reports a lost run
reset_state
"$tool" codex bash -c 'echo $$ > "$TMPDIR/state/command-pid"; exec sleep 300' >"$tmp/out" 2>"$tmp/err" &
helper=$!
for _ in {1..300}; do
  [[ -e $TEST_STATE/command-pid ]] && break
  sleep 0.01
done
runner=$(find "$TMPDIR" -name runner.pid -path '*/tmp.*/*' -print -quit 2>/dev/null || :)
kill -TERM "$(cat "$runner")"
code=0
wait "$helper" || code=$?
assert_code 1
grep -qF 'run lost' "$tmp/err"
if kill -0 "$(cat "$TEST_STATE/command-pid")" 2>/dev/null; then exit 1; fi
ok runner-signalled

# a herdr socket error while placing the tab: the run still happens, once
reset_state
: >"$TEST_STATE/socket-error"
printf '9\n' >>"$TEST_STATE/tabs" # a tab after the lead, so the pane lookup runs
run_capture bash -c 'printf "x\n" >> "$TMPDIR/state/runs"'
assert_code 0
count_runs 1
ok socket-error

# SIGTERM to herdr-run in the headless fallback reaches the command
reset_state
: >"$TEST_STATE/fail-tab-create"
"$tool" codex bash -c 'echo $$ > "$TMPDIR/state/command-pid"; exec sleep 300' >/dev/null 2>&1 &
helper=$!
for _ in {1..300}; do
  [[ -e $TEST_STATE/command-pid ]] && break
  sleep 0.01
done
kill -TERM "$helper"
code=0
wait "$helper" || code=$?
assert_code 143
if kill -0 "$(cat "$TEST_STATE/command-pid")" 2>/dev/null; then exit 1; fi
ok headless-term

# an exported value with newlines (and a line that looks like an excluded name) arrives intact
reset_state
export AGY_GUARD_LOG=$'one\nBASH_LOOKALIKE="two\nthree'
run_capture bash -c 'printf %s "$AGY_GUARD_LOG"'
unset AGY_GUARD_LOG
assert_code 0
[[ $(cat "$tmp/out") == $'one\nBASH_LOOKALIKE="two\nthree' ]]
ok multiline-env

# kill -9 of the helper; the command dies on TERM but its child ignores it: the child is KILLed too
reset_state
"$tool" codex bash -c '(trap "" TERM; exec sleep 300) & echo $! > "$TMPDIR/state/child-pid"; wait' >/dev/null 2>&1 &
helper=$!
for _ in {1..300}; do
  [[ -e $TEST_STATE/child-pid ]] && break
  sleep 0.01
done
kill -KILL "$helper"
wait "$helper" 2>/dev/null || :
for _ in {1..200}; do
  kill -0 "$(cat "$TEST_STATE/child-pid")" 2>/dev/null || break
  sleep 0.02
done
if kill -0 "$(cat "$TEST_STATE/child-pid")" 2>/dev/null; then exit 1; fi
ok term-resistant-child

# stdin that never sends EOF (Claude Code's Bash tool gives a socket): a command
# that does not read stdin still finishes, and no feeder is left behind (#2679)
holders() {
  local p n=0
  for p in /proc/[0-9]*; do
    [[ $(readlink "$p/fd/0" 2>/dev/null) == "$tmp/never" ]] && n=$((n + 1))
  done
  echo "$n"
}
mkfifo "$tmp/never"
exec 7<>"$tmp/never"
reset_state
code=0
timeout 20 "$tool" codex bash -c 'printf "hi\n"' <"$tmp/never" >"$tmp/out" 2>"$tmp/err" || code=$?
assert_code 0
[[ $(cat "$tmp/out") == hi ]]
sleep 0.5
[[ $(holders) == 0 ]]
ok stdin-never-closes

reset_state
: >"$TEST_STATE/fail-tab-create"
code=0
timeout 20 "$tool" codex bash -c 'printf "hi\n"' <"$tmp/never" >"$tmp/out" 2>"$tmp/err" || code=$?
assert_code 0
[[ $(cat "$tmp/out") == hi ]]
sleep 0.5
[[ $(holders) == 0 ]]
ok stdin-never-closes-headless

# kill -9 of the helper while stdin stays open: the feeder and the command go too
reset_state
"$tool" codex bash -c 'echo $$ > "$TMPDIR/state/command-pid"; exec sleep 300' <"$tmp/never" >/dev/null 2>&1 &
helper=$!
for _ in {1..300}; do
  [[ -e $TEST_STATE/command-pid ]] && break
  sleep 0.01
done
kill -KILL "$helper"
wait "$helper" 2>/dev/null || :
for _ in {1..200}; do
  [[ $(holders) == 0 ]] && ! kill -0 "$(cat "$TEST_STATE/command-pid")" 2>/dev/null && break
  sleep 0.02
done
[[ $(holders) == 0 ]]
if kill -0 "$(cat "$TEST_STATE/command-pid")" 2>/dev/null; then exit 1; fi
ok helper-killed-open-stdin

# the helper's whole group is killed before any runner starts; the late runner,
# blocked opening the FIFO with no writer left, must still end (no hang)
reset_state
: >"$TEST_STATE/no-claim"
# setsid execs in place here (an async job is no group leader), so $! is both
# the helper's PID and its process-group ID; never search for it by name
setsid "$tool" codex bash -c 'printf x >> "$TMPDIR/state/runs"' <"$tmp/never" >/dev/null 2>&1 &
group=$!
for _ in {1..300}; do
  [[ -s $TEST_STATE/late-line ]] && break
  sleep 0.01
done
[[ $(ps -o pgid= -p "$group" | tr -d ' ') == "$group" ]]
kill -KILL -- "-$group"
code=0
timeout 15 bash -c "$(cat "$TEST_STATE/late-line")" >/dev/null 2>&1 || code=$?
[[ $code != 124 ]]
ok group-killed-before-runner

# the headless fallback hands the command the caller's stdin, unread
reset_state
: >"$TEST_STATE/fail-tab-create"
code=0
out=$({
  printf 'line one\n'
  sleep 30
} | timeout 20 "$tool" codex bash -c 'read -r l; printf "%s\n" "$l"') || code=$?
assert_code 0
[[ $out == "line one" ]]
ok headless-keeps-stdin

# only allow-listed names reach the command, by name, never by value
eval "$(sed -n '/^agent_env_base=(/,/^agent_env_exported() {/{/^agent_env_exported/d;p}' "$tool")"
declare -A allowed=()
# shellcheck disable=SC2154  # agent_env_names comes from the eval above
for n in "${agent_env_names[@]}" PWD SHLVL _ OLDPWD; do allowed[$n]=1; done
names_cmd='env -0 | cut -z -d= -f1 | tr "\0" "\n"'
marker=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')

reset_state
export HERDR_RUN_TEST_DECOY=$marker
HERDR_ENV=0 "$tool" codex bash -c "$names_cmd" >"$tmp/out" 2>"$tmp/err" </dev/null
grep -qx HERDR_RUN_TEST_DECOY "$tmp/out"
unset HERDR_RUN_TEST_DECOY
ok headless-env

reset_state
export GITHUB_API_TOKEN=$marker HERDR_RUN_TEST_DECOY=$marker SSH_AUTH_SOCK=$marker HERDR_PANE_ID=$marker
# A login shell's NIX_CONFIG carries the GitHub token (api-keys.nix), so it must not pass (#2762 review).
export NIX_CONFIG="access-tokens = github.com=$marker"
"$tool" codex bash -c 'touch "$TMPDIR/state/started"; timeout 10 bash -c "until [ -e \$TMPDIR/state/go ]; do sleep 0.01; done"; '"$names_cmd" >"$tmp/out" 2>"$tmp/err" </dev/null &
helper=$!
for _ in {1..300}; do
  [[ -e $TEST_STATE/started ]] && break
  sleep 0.01
done
[[ -e $TEST_STATE/started ]]
if grep -rqF -- "$marker" "$tmp"/tmp.*/; then exit 1; fi
envfiles=("$tmp"/tmp.*/env)
[[ ${#envfiles[@]} == 1 && -f ${envfiles[0]} ]]
while IFS= read -r n; do [[ -n ${allowed[$n]:-} ]] || exit 1; done < <(sed -n 's/^declare -[^ ]* \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "${envfiles[0]}")
: >"$TEST_STATE/go"
code=0
wait "$helper" || code=$?
assert_code 0
[[ -s $tmp/out ]]
while IFS= read -r n; do [[ -n ${allowed[$n]:-} ]] || exit 1; done <"$tmp/out"
if grep -qxE 'GITHUB_API_TOKEN|HERDR_RUN_TEST_DECOY|SSH_AUTH_SOCK|HERDR_PANE_ID|NIX_CONFIG' "$tmp/out"; then exit 1; fi
unset GITHUB_API_TOKEN HERDR_RUN_TEST_DECOY SSH_AUTH_SOCK HERDR_PANE_ID NIX_CONFIG
ok env-allow-list
exec 7>&-
