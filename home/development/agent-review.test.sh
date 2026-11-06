#!/usr/bin/env bash
# Run by hand from a worktree: bash home/development/agent-review.test.sh < /dev/null
# Not part of checkPhase: the sandbox cases need user namespaces. No login, no real codex.
# Exit 1 on any mismatch. Never prints environment values.
here=$(cd "$(dirname "$0")" && pwd)
script=$here/agent-review.sh
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1
w=$(mktemp -d /tmp/agent-review-test.XXXXXX)
trap 'rm -rf "$w"' EXIT
mkdir -p "$w/bin" "$w/work" "$w/fakebwrap"

# Fake codex: records that it ran, its args, and the names of its environment variables.
cat >"$w/work/bin-codex" <<'FAKE'
#!/usr/bin/env bash
w=$(dirname "$0")
: >"$w/ran"
printf '%s\n' "$@" >"$w/args"
env | cut -d= -f1 | sort >"$w/envnames"
{
  for p in /run/agenix /mnt /var "$HOME/.ssh" /nix/var/nix/daemon-socket/socket; do
    [ -e "$p" ] && echo "present $p"
  done
  [ -w "$PWD" ] && echo "worktree-writable"
  [ -w "$w" ] && echo "workdir-writable"
} >"$w/probe" 2>&1
FAKE
mkdir -p "$w/work/bin"
mv "$w/work/bin-codex" "$w/work/bin/codex"
chmod +x "$w/work/bin/codex"
printf '#!/bin/sh\nexit 1\n' >"$w/fakebwrap/bwrap"
chmod +x "$w/fakebwrap/bwrap"

fail=0
ok() { printf 'ok   %s\n' "$1"; }
bad() {
  printf 'FAIL %s\n' "$1"
  fail=1
}
reset() { rm -f "$w/work/bin/ran" "$w/work/bin/args" "$w/work/bin/envnames" "$w/work/bin/probe"; }

# run <args...>: run the wrapper with the fake codex first on PATH.
run() {
  reset
  PATH="$w/work/bin:$PATH" bash "$script" "$@" >/dev/null 2>&1 </dev/null
}
# refused <label> <dir> <args...>: must exit 2 and never start codex.
refused() {
  local label=$1
  shift
  run "$@"
  local rc=$?
  if [ $rc -eq 2 ] && [ ! -e "$w/work/bin/ran" ]; then ok "$label"; else bad "$label (rc=$rc)"; fi
}

W=$w/work
refused 'agy' x agy "$W" -- exec
refused 'missing --' codex "$W" exec
refused 'no args after --' codex "$W" --
for sub in mcp login sandbox; do refused "subcommand $sub" codex "$W" -- "$sub"; done
for a in --dangerously-bypass-approvals-and-sandbox --yolo --full-auto; do refused "$a" codex "$W" -- exec "$a"; done
refused '--add-dir x' codex "$W" -- exec --add-dir x
refused '--model x' codex "$W" -- exec --model x
refused '-p implement' codex "$W" -- exec -p implement
refused '--profile=implement' codex "$W" -- exec --profile=implement
refused '--enable x' codex "$W" -- exec --enable x
refused '--oss' codex "$W" -- exec --oss
refused '-s workspace-write' codex "$W" -- exec -s workspace-write
refused '--sandbox=danger-full-access' codex "$W" -- exec --sandbox=danger-full-access
refused '-sdanger-full-access' codex "$W" -- exec -sdanger-full-access
refused '-pimplement' codex "$W" -- exec -pimplement
refused '-a never' codex "$W" -- exec -a never
refused '--ask-for-approval=never' codex "$W" -- exec --ask-for-approval=never
refused '--search' codex "$W" -- exec --search
refused 'unknown long option' codex "$W" -- review --some-future-flag
for k in sandbox_mode mcp_servers model_provider; do
  refused "-c $k" codex "$W" -- exec -c "$k=v"
  refused "-c$k" codex "$W" -- exec "-c$k=v"
  refused "-c=$k" codex "$W" -- exec "-c=$k=v"
  refused "--config $k" codex "$W" -- exec --config "$k=v"
  refused "--config=$k" codex "$W" -- exec "--config=$k=v"
done
reset
HUMANIZE_CODEX_BYPASS_SANDBOX=1 PATH="$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null
if [ $? -eq 2 ] && [ ! -e "$W/bin/ran" ]; then ok 'HUMANIZE_CODEX_BYPASS_SANDBOX'; else bad 'HUMANIZE_CODEX_BYPASS_SANDBOX'; fi

ln -s "$W" "$w/link"
refused 'work dir symlink' codex "$w/link" -- exec
refused 'work dir outside /tmp' codex /etc -- exec
refused 'work dir equals worktree' codex "$root" -- exec
refused 'work dir inside worktree' codex "$root/home" -- exec
refused 'work dir contains worktree' codex "$(dirname "$root")" -- exec

# A failing bwrap: codex must not run, exit non-zero.
reset
PATH="$w/fakebwrap:$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null
rc=$?
if [ $rc -ne 0 ] && [ ! -e "$W/bin/ran" ]; then ok 'failing bwrap'; else bad "failing bwrap (rc=$rc)"; fi

# Real sandbox.
if command -v bwrap >/dev/null && bwrap --ro-bind / / true >/dev/null 2>&1; then
  reset
  PATH="$W/bin:$PATH" bash "$script" codex "$W" -- exec -c model=x >/dev/null 2>&1 </dev/null
  rc=$?
  if [ $rc -eq 0 ] && [ -e "$W/bin/ran" ]; then ok 'allowed call runs'; else bad "allowed call runs (rc=$rc)"; fi
  for opt in forced_login_method=chatgpt 'mcp_servers={}' 'sandbox_mode="read-only"' model=x; do
    if grep -qxF -- "$opt" "$W/bin/args"; then ok "arg $opt"; else bad "arg $opt"; fi
  done
  if [ -s "$W/bin/probe" ]; then
    while IFS= read -r l; do
      case $l in
        present*) bad "sandbox leaks: $l" ;;
        worktree-writable) bad 'worktree is writable' ;;
      esac
    done <"$W/bin/probe"
  fi
  if grep -qx workdir-writable "$W/bin/probe"; then ok 'work dir writable'; else bad 'work dir not writable'; fi
  grep -q present "$W/bin/probe" || ok 'secret and daemon paths absent'
  grep -qx worktree-writable "$W/bin/probe" || ok 'worktree read-only'
  extra=$(grep -vxE 'HOME|TMPDIR|PATH|LANG|TERM|SSL_CERT_FILE|NIX_REMOTE|NIX_CONFIG|PWD|OLDPWD|SHLVL|_' "$W/bin/envnames")
  if [ -z "$extra" ]; then ok 'environment only listed variables'; else bad "unexpected env names: $extra"; fi
else
  echo 'SKIP sandbox checks: real bwrap or user namespaces unavailable (not counted as pass)'
fi

[ $fail -eq 0 ] && echo 'ALL PASSED' || echo 'FAILURES'
exit $fail
