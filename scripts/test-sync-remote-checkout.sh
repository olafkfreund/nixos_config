#!/usr/bin/env bash
set -euo pipefail

script=$(cd "$(dirname "$0")" && pwd)/sync-remote-checkout.sh
real_git=$(command -v git)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config"
export TEST_HOME="$tmp/home" TEST_SSH_MARKER="$tmp/ssh-called" REAL_GIT="$real_git"
cat >"$tmp/bin/ssh" <<'SSH'
#!/usr/bin/env bash
printf x > "$TEST_SSH_MARKER"
[[ ${TEST_SSH_FAIL:-} == 1 ]] && exit 255
while [[ ${1:-} == -o ]]; do shift 2; done
shift
HOME=$TEST_HOME "$@"
SSH
cat >"$tmp/bin/hostname" <<'HOSTNAME'
#!/usr/bin/env bash
printf 'testhost\n'
HOSTNAME
cat >"$tmp/bin/git" <<'GIT'
#!/usr/bin/env bash
if [[ ${TEST_EDIT_AFTER_STATUS:-} == 1 && $PWD == "$TEST_HOME/.config/nixos" && ${1:-} == fetch && ! -e $TEST_HOME/edited ]]; then
  printf 'local edit\n' > tracked
  touch "$TEST_HOME/edited"
fi
exec "$REAL_GIT" "$@"
GIT
chmod +x "$tmp/bin/ssh" "$tmp/bin/hostname" "$tmp/bin/git"
export PATH="$tmp/bin:$PATH"
g() { "$real_git" "$@"; }

setup() {
  rm -rf "$tmp/origin.git" "$tmp/src" "$TEST_HOME/.config/nixos" "$TEST_SSH_MARKER" "$TEST_HOME/edited"
  g init -q --bare -b main "$tmp/origin.git"
  g clone -q "$tmp/origin.git" "$tmp/src"
  g -C "$tmp/src" config user.name Test
  g -C "$tmp/src" config user.email test@example.invalid
  printf 'base\n' >"$tmp/src/tracked"
  g -C "$tmp/src" add tracked
  g -C "$tmp/src" commit -qm base
  g -C "$tmp/src" push -q origin main
  g clone -q "$tmp/origin.git" "$TEST_HOME/.config/nixos"
  g -C "$TEST_HOME/.config/nixos" config user.name Test
  g -C "$TEST_HOME/.config/nixos" config user.email test@example.invalid
  base=$(g -C "$tmp/src" rev-parse HEAD)
  base_tree=$(g -C "$tmp/src" rev-parse 'HEAD^{tree}')
}

advance() {
  printf '%s\n' "$1" >"$tmp/src/tracked"
  g -C "$tmp/src" add tracked
  g -C "$tmp/src" commit -qm "$1"
  g -C "$tmp/src" push -q origin main
  newer_tree=$(g -C "$tmp/src" rev-parse 'HEAD^{tree}')
}

run() {
  if output=$(cd "$tmp/src" && "$script" "$@" 2>&1); then result=0; else result=$?; fi
}

check() {
  local label=$1 expected_head=$2 expected_line=$3 expected_result=${4:-0}
  [[ $result == "$expected_result" ]] || {
    printf '%s: exit %s, wanted %s\n' "$label" "$result" "$expected_result" >&2
    exit 1
  }
  [[ $(g -C "$TEST_HOME/.config/nixos" rev-parse HEAD) == "$expected_head" ]] || {
    printf '%s: target HEAD changed unexpectedly\n' "$label" >&2
    exit 1
  }
  [[ $output == "checkout sync (razer): $expected_line" ]] || {
    printf '%s: unexpected output: %s\n' "$label" "$output" >&2
    exit 1
  }
}

setup
run around razer -- false
check 'failed command' "$base" 'command failed; skipped' 1
[[ ! -e $TEST_SSH_MARKER ]]

setup
run around razer -- bash -c "printf newer > tracked; '$real_git' add tracked; '$real_git' commit -qm newer; '$real_git' push -q origin main"
check 'tree before command' "$base" 'already current'
[[ -e $TEST_SSH_MARKER && $(g -C "$tmp/src" rev-parse HEAD) != "$base" ]]

setup
printf dirty >"$tmp/src/untracked"
run around razer -- true
check 'dirty source' "$base" 'dirty source; skipped'
[[ ! -e $TEST_SSH_MARKER ]]

setup
g -C "$tmp/src" switch -qc feature
run around razer -- true
check 'feature branch' "$base" 'source not on main or origin/main; skipped'
[[ ! -e $TEST_SSH_MARKER ]]

setup
advance newer
g -C "$tmp/src" switch -qc feature
run around razer -- true
check 'feature tree on main' "$base" 'source not on main or origin/main; skipped'
[[ ! -e $TEST_SSH_MARKER ]]

setup
g -C "$tmp/src" switch -qc feature
printf squash >"$tmp/src/tracked"
g -C "$tmp/src" add tracked
g -C "$tmp/src" commit -qm feature
squash_tree=$(g -C "$tmp/src" rev-parse 'HEAD^{tree}')
g -C "$tmp/src" switch -q main
g -C "$tmp/src" merge -q --squash feature
g -C "$tmp/src" commit -qm squash
g -C "$tmp/src" push -q origin main
squash_commit=$(g -C "$tmp/src" rev-parse HEAD)
run sync razer "$squash_tree"
check 'squash tree' "$squash_commit" "fast-forwarded $base..$squash_commit (1 commits)"

setup
g -C "$tmp/src" switch -qc feature
printf feature >"$tmp/src/tracked"
g -C "$tmp/src" add tracked
g -C "$tmp/src" commit -qm feature
feature_tree=$(g -C "$tmp/src" rev-parse 'HEAD^{tree}')
g -C "$tmp/src" switch -q main
advance other
run sync razer "$feature_tree"
check 'tree absent from main' "$base" 'tree not on origin/main; skipped'
[[ ! -e $TEST_SSH_MARKER ]]

setup
advance newer
printf dirty >"$TEST_HOME/.config/nixos/untracked"
run sync razer "$newer_tree"
check 'dirty target' "$base" 'dirty target; skipped'

setup
advance newer
g -C "$TEST_HOME/.config/nixos" switch -qc other
run sync razer "$newer_tree"
check 'other target branch' "$base" 'not on main; skipped'

setup
advance newer
printf local >"$TEST_HOME/.config/nixos/local"
g -C "$TEST_HOME/.config/nixos" add local
g -C "$TEST_HOME/.config/nixos" commit -qm local
local_head=$(g -C "$TEST_HOME/.config/nixos" rev-parse HEAD)
run sync razer "$newer_tree"
check 'diverged target' "$local_head" 'target is not an ancestor; skipped'

setup
printf tracked >"$tmp/src/blocked"
g -C "$tmp/src" add blocked
g -C "$tmp/src" commit -qm blocked
g -C "$tmp/src" push -q origin main
blocked_tree=$(g -C "$tmp/src" rev-parse 'HEAD^{tree}')
printf 'blocked\n' >"$TEST_HOME/.config/nixos/.git/info/exclude"
printf 'local ignored content\n' >"$TEST_HOME/.config/nixos/blocked"
run sync razer "$blocked_tree"
check 'ignored collision' "$base" 'could not sync: fast-forward failed'
[[ $(cat "$TEST_HOME/.config/nixos/blocked") == 'local ignored content' ]]

setup
advance newer
g -C "$TEST_HOME/.config/nixos" config merge.autostash true
TEST_EDIT_AFTER_STATUS=1 run sync razer "$newer_tree"
check 'autostash forbidden' "$base" 'could not sync: fast-forward failed'
[[ $(cat "$TEST_HOME/.config/nixos/tracked") == 'local edit' ]]
[[ -z $(g -C "$TEST_HOME/.config/nixos" stash list) ]]

setup
advance newer
TEST_SSH_FAIL=1 run sync razer "$newer_tree"
check 'ssh failed' "$base" 'could not sync: ssh failed'

setup
advance newer
g -C "$tmp/src" switch -q --detach origin/main
run around razer -- true
check 'detached at origin/main' "$(g -C "$tmp/src" rev-parse HEAD)" "fast-forwarded $base..$(g -C "$tmp/src" rev-parse HEAD) (1 commits)"

setup
advance newer
g -C "$tmp/src" switch -q --detach "$base"
run around razer -- true
check 'detached elsewhere' "$base" 'source not on main or origin/main; skipped'
[[ ! -e $TEST_SSH_MARKER ]]

setup
advance newer
run around razer -- bash -c 'printf edit > tracked'
check 'edited during command' "$base" 'source changed during the command; skipped'
[[ ! -e $TEST_SSH_MARKER ]]

setup
run sync p620 "$base_tree"
[[ $result == 0 && $output == 'checkout sync (p620): local host; skipped' && ! -e $TEST_SSH_MARKER ]]
run sync testhost "$base_tree"
[[ $result == 0 && $output == 'checkout sync (testhost): local host; skipped' && ! -e $TEST_SSH_MARKER ]]

printf 'sync-remote-checkout tests passed\n'
