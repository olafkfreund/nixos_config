#!/usr/bin/env bash
set -euo pipefail

source_script=$(cd "$(dirname "$0")" && pwd)/update-commit-deploy.sh
real_git=$(command -v git)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/flake.lock" <<'JSON'
{"nodes":{"root":{"inputs":{"nixpkgs":"nixpkgs"}},"nixpkgs":{"locked":{"rev":"old","lastModified":1,"type":"github"}}}}
JSON

mkdir "$tmp/bin"
cat >"$tmp/bin/hostname" <<'SH'
#!/usr/bin/env bash
printf 'testhost\n'
SH
cat >"$tmp/bin/nix" <<'SH'
#!/usr/bin/env bash
if [[ $1 == flake && $2 == update ]]; then
  if [[ $CASE == changed || $CASE == no_deploy_changed || $CASE == merge_fail || $CASE == pull_fail || $CASE == health_fail ]]; then
    jq '.nodes.nixpkgs.locked.rev = "new" | .nodes.nixpkgs.locked.lastModified = 2' flake.lock >flake.lock.tmp
    mv flake.lock.tmp flake.lock
  fi
elif [[ $1 == eval ]]; then
  printf '/nix/store/new\n'
else
  exit 1
fi
SH
cat >"$tmp/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  'api '*) exit 1 ;;
  'pr create') printf 'https://example.invalid/pr/1\n' ;;
  'pr merge')
    [[ $CASE != merge_fail ]] || exit 1
    "$REAL_GIT" -C "$MERGE_DIR" fetch -q origin "$BRANCH_FOR_TEST"
    "$REAL_GIT" -C "$MERGE_DIR" merge --squash -q FETCH_HEAD
    printf 'later\n' >"$MERGE_DIR/after-activation"
    "$REAL_GIT" -C "$MERGE_DIR" add .
    "$REAL_GIT" -C "$MERGE_DIR" commit -qm merged
    "$REAL_GIT" -C "$MERGE_DIR" push -q origin main
    ;;
  'pr close') : ;;
  *) exit 1 ;;
esac
SH
cat >"$tmp/bin/ssh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *'readlink -f /nix/var/nix/profiles/system'*)
    if [[ -e $RUN_DIR/activated ]]; then printf '/nix/store/new\n'; else printf '/nix/store/old\n'; fi ;;
  *'readlink /run/current-system'*)
    if [[ $CASE == noop || ( -e $RUN_DIR/activated && $CASE != boot ) ]]; then
      printf '/nix/store/new\n'
    else
      printf '/nix/store/old\n'
    fi ;;
  *'bash -s'*)
    cat >/dev/null
    [[ $CASE != health_fail ]] ;;
  *) : ;;
esac
SH
cat >"$tmp/bin/nh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  'os build') : ;;
  'os switch'|'os boot')
    [[ $CASE != activation_fail ]] || exit 1
    "$REAL_GIT" rev-parse 'HEAD^{tree}' >"$RUN_DIR/activation-tree"
    touch "$RUN_DIR/activated" ;;
  *) exit 1 ;;
esac
SH
cat >"$tmp/bin/git" <<'SH'
#!/usr/bin/env bash
if [[ $1 == pull && $CASE == pull_fail ]]; then exit 1; fi
exec "$REAL_GIT" "$@"
SH
cat >"$tmp/bin/readlink" <<'SH'
#!/usr/bin/env bash
case "$*" in
  '/run/current-system') printf '/nix/store/new\n' ;;
  '-f /nix/var/nix/profiles/system') printf '/nix/store/new\n' ;;
  *) /usr/bin/readlink "$@" ;;
esac
SH
cat >"$tmp/bin/sleep" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$tmp/bin/nixos-rebuild" <<'SH'
#!/usr/bin/env bash
printf 'unexpected nixos-rebuild invocation\n' >&2
exit 1
SH
cat >"$tmp/bin/recorder" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RUN_DIR/calls"
[[ $CASE != recorder_fail ]]
SH
chmod +x "$tmp/bin/"*

fail() {
  printf 'FAIL %s: %s\n' "$CASE" "$1" >&2
  cat "$RUN_DIR/output" >&2
  exit 1
}

run_case() {
  CASE=$1
  RUN_DIR="$tmp/$CASE"
  mkdir -p "$RUN_DIR"
  "$real_git" init -q --bare "$RUN_DIR/origin"
  "$real_git" -C "$RUN_DIR/origin" symbolic-ref HEAD refs/heads/main
  "$real_git" clone -q "$RUN_DIR/origin" "$RUN_DIR/src"
  mkdir -p "$RUN_DIR/src/scripts/health-checks"
  "$real_git" -C "$RUN_DIR/src" config user.name Test
  "$real_git" -C "$RUN_DIR/src" config user.email test@example.invalid
  cp "$source_script" "$RUN_DIR/src/scripts/update-commit-deploy.sh"
  cp "$tmp/flake.lock" "$RUN_DIR/src/flake.lock"
  cat >"$RUN_DIR/src/scripts/check-boot-space.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  cat >"$RUN_DIR/src/scripts/health-checks/razer.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$RUN_DIR/src/scripts/"*.sh "$RUN_DIR/src/scripts/health-checks/razer.sh"
  "$real_git" -C "$RUN_DIR/src" add .
  "$real_git" -C "$RUN_DIR/src" commit -qm initial
  "$real_git" -C "$RUN_DIR/src" push -q origin main
  "$real_git" clone -q "$RUN_DIR/origin" "$RUN_DIR/merge"
  "$real_git" -C "$RUN_DIR/merge" config user.name Test
  "$real_git" -C "$RUN_DIR/merge" config user.email test@example.invalid
  MERGE_DIR="$RUN_DIR/merge"
  export CASE RUN_DIR MERGE_DIR REAL_GIT="$real_git" NHS_SYNC_CMD="$tmp/bin/recorder"
  export PATH="$tmp/bin:$PATH" NIX_CONFIG='access-tokens = test'
  local host=razer expected_rc=0
  [[ $CASE != boot ]] || host=p510
  [[ $CASE != local ]] || host=testhost
  local args=("$host" all)
  [[ $CASE != no_deploy_unchanged && $CASE != no_deploy_changed ]] || args+=(--no-deploy)
  if [[ $CASE == changed || $CASE == no_deploy_changed || $CASE == merge_fail || $CASE == pull_fail || $CASE == health_fail ]]; then
    # The branch name is derived from the changed lock; the stub needs it after the push.
    local changed_lock
    changed_lock=$(jq '.nodes.nixpkgs.locked.rev = "new" | .nodes.nixpkgs.locked.lastModified = 2' "$RUN_DIR/src/flake.lock")
    BRANCH_FOR_TEST="chore/lock-bump-all-$(printf '%s\n' "$changed_lock" | "$real_git" hash-object --stdin | cut -c1-8)"
    export BRANCH_FOR_TEST
  fi
  [[ $CASE != activation_fail && $CASE != health_fail && $CASE != pull_fail ]] || expected_rc=1
  local rc=0
  (cd "$RUN_DIR/src" && bash scripts/update-commit-deploy.sh "${args[@]}") >"$RUN_DIR/output" 2>&1 || rc=$?
  [[ $rc == "$expected_rc" ]] || fail "exit $rc, expected $expected_rc"
  local expected_calls=0 expected_tree=
  case $CASE in
    noop)
      expected_calls=1
      expected_tree=$("$real_git" -C "$RUN_DIR/src" rev-parse 'HEAD^{tree}')
      ;;
    no_pr | boot | changed | recorder_fail)
      expected_calls=1
      expected_tree=$(cat "$RUN_DIR/activation-tree")
      ;;
  esac
  local actual_calls=0
  [[ ! -e $RUN_DIR/calls ]] || actual_calls=$(wc -l <"$RUN_DIR/calls")
  [[ $actual_calls == "$expected_calls" ]] || fail "$actual_calls sync calls, expected $expected_calls"
  if [[ $expected_calls == 1 ]]; then
    [[ $(cat "$RUN_DIR/calls") == "sync $host $expected_tree" ]] || fail "wrong sync arguments"
  fi
  if [[ $CASE == changed ]]; then
    [[ $("$real_git" -C "$RUN_DIR/src" rev-parse 'HEAD^{tree}') != "$expected_tree" ]] || fail 'post-merge tree did not differ'
  fi
  printf 'ok %s\n' "$CASE"
}

for case_name in no_pr changed noop boot activation_fail health_fail no_deploy_unchanged no_deploy_changed local merge_fail pull_fail recorder_fail; do
  run_case "$case_name"
done
