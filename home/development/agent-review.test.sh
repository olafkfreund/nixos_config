#!/usr/bin/env bash
# Run by hand from a worktree: bash home/development/agent-review.test.sh < /dev/null
# Not part of checkPhase: the sandbox cases need user namespaces. No login, no real codex.
# Exit 1 on any mismatch, 77 if a check could not run (SKIP, never a pass). Never prints environment values.
# AGENT_REVIEW=<path> tests another copy of the wrapper (mutation checks).
here=$(cd "$(dirname "$0")" && pwd)
script=${AGENT_REVIEW:-$here/agent-review.sh}
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
  c=$(realpath "$(git rev-parse --git-common-dir)" 2>/dev/null)
  if [ -z "$c" ]; then echo common-unknown; elif [ -w "$c" ]; then echo common-writable; fi
  [ -r "$HOME/.codex/auth.json" ] && echo auth-visible
  for f in "$HOME/.codex"/* "$HOME/.codex"/.[!.]*; do
    [ -e "$f" ] && [ "${f##*/}" != auth.json ] && echo "codex-extra ${f##*/}"
  done
  for f in history.jsonl config.toml hooks.json hooks; do
    [ -e "$HOME/.codex/$f" ] && echo "codex-extra $f"
  done
} >"$w/probe" 2>&1
exit 0
FAKE
mkdir -p "$w/work/bin"
mv "$w/work/bin-codex" "$w/work/bin/codex"
chmod +x "$w/work/bin/codex"
printf '#!/bin/sh\nexit 1\n' >"$w/fakebwrap/bwrap"
chmod +x "$w/fakebwrap/bwrap"

fail=0
skipped=0
ok() { printf 'ok   %s\n' "$1"; }
skip() {
  printf 'SKIP %s (not counted as pass)\n' "$1"
  skipped=1
}
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
refused 'agy is refused' agy "$W" -- exec
refused 'agy is refused with review' agy "$W" -- review
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

if ! command -v bwrap >/dev/null || ! bwrap --ro-bind / / true >/dev/null 2>&1; then
  skip 'planted codex checks: real bwrap or user namespaces unavailable'
elif [ ! -f "$HOME/.codex/auth.json" ]; then
  skip 'planted codex checks: no codex dir/auth.json to mount'
else
  # A codex planted in the reviewed repo, found through a relative or in-repo PATH entry, must never run.
  plant=$w/plant
  git init -q "$plant"
  printf '#!/bin/sh\ntouch %s/planted\n' "$W" >"$plant/codex"
  chmod +x "$plant/codex"
  rm -f "$W/planted"
  rm -f "$W/bin/ran"
  (cd "$plant" && PATH="/nonexistent::.:$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null)
  rc=$?
  if [ ! -e "$W/planted" ] && [ -e "$W/bin/ran" ]; then ok 'codex planted in the repo, empty PATH entry'; else bad "codex planted in the repo, empty PATH entry (rc=$rc)"; fi
  rm -f "$W/planted"
  rm -f "$W/bin/ran"
  (cd "$plant" && PATH="$plant:$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null)
  rc=$?
  if [ ! -e "$W/planted" ] && [ -e "$W/bin/ran" ]; then ok 'codex planted in the repo, absolute PATH entry'; else bad "codex planted in the repo, absolute PATH entry (rc=$rc)"; fi
  ln -sfn "$plant" "$W/plantlink"
  rm -f "$W/planted" "$W/bin/ran"
  (cd "$plant" && PATH="$W/plantlink:$w/./plant:$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null)
  rc=$?
  if [ ! -e "$W/planted" ] && [ -e "$W/bin/ran" ]; then ok 'codex planted in the repo, symlinked or /./ PATH entry'; else bad "codex planted in the repo, symlinked or /./ PATH entry (rc=$rc)"; fi
  rm -f "$W/plantlink"
fi
refused 'work dir equals worktree' codex "$root" -- exec
refused 'work dir inside worktree' codex "$root/home" -- exec
refused 'work dir contains worktree' codex "$(dirname "$root")" -- exec

refused 'work dir under HOME' codex "$HOME" -- exec
if [ -d "${XDG_RUNTIME_DIR:-}" ] && x=$(mktemp -d "$XDG_RUNTIME_DIR/agent-review-test.XXXXXX"); then
  refused 'work dir under XDG_RUNTIME_DIR' codex "$x" -- exec
  rmdir "$x"
else
  skip 'XDG_RUNTIME_DIR work dir check: no writable XDG_RUNTIME_DIR'
fi
mkdir -p "$w/real/sub"
ln -s "$w/real" "$w/plink"
refused 'work dir with symlinked parent' codex "$w/plink/sub" -- exec
refused '-o outside work dir' codex "$W" -- exec -o /etc/agent-review-test
refused '-o with .. escape' codex "$W" -- exec -o "$W/../escape"
refused '--output-last-message outside' codex "$W" -- exec --output-last-message="$w/escape"
refused '--output-last-message value outside' codex "$W" -- exec --output-last-message "$w/escape"

# Throwaway repo under /tmp: the real worktree is not under /tmp, so it cannot test overlap.
mkdir -p "$w/repo/sub"
git init -q "$w/repo"
pushd "$w/repo" >/dev/null || exit 1
refused 'overlap: work dir equals repo' codex "$w/repo" -- exec
refused 'overlap: work dir inside repo' codex "$w/repo/sub" -- exec
refused 'overlap: work dir equals git dir' codex "$w/repo/.git" -- exec
refused 'overlap: work dir inside git dir' codex "$w/repo/.git/refs" -- exec
refused 'overlap: work dir contains repo' codex "$w" -- exec
popd >/dev/null || exit 1

mkdir -p "$w/sockdir"
if command -v python3 >/dev/null && python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$w/sockdir/s"; then
  refused 'work dir containing a socket' codex "$w/sockdir" -- exec
else
  skip 'socket check: cannot create a unix socket'
fi

# A git that claims HOME is the repo root.
mkdir -p "$w/stubgit"
cat >"$w/stubgit/git" <<'STUB'
#!/bin/sh
case $* in
  *--is-inside-work-tree*) echo true ;;
  *) echo "$HOME" ;;
esac
STUB
chmod +x "$w/stubgit/git"
reset
PATH="$w/stubgit:$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null
rc=$?
if [ $rc -eq 2 ] && [ ! -e "$W/bin/ran" ]; then ok 'repo root equals HOME'; else bad "repo root equals HOME (rc=$rc)"; fi

# A failing bwrap: codex must not run, exit non-zero.
reset
PATH="$w/fakebwrap:$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null
rc=$?
if [ $rc -ne 0 ] && [ ! -e "$W/bin/ran" ]; then ok 'failing bwrap'; else bad "failing bwrap (rc=$rc)"; fi

# Real sandbox.
if ! command -v bwrap >/dev/null || ! bwrap --ro-bind / / true >/dev/null 2>&1; then
  skip 'sandbox checks: real bwrap or user namespaces unavailable'
elif [ ! -f "$HOME/.codex/auth.json" ]; then
  skip 'sandbox checks: no codex dir/auth.json to mount'
else
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
        common-writable | common-unknown) bad "git common dir: $l" ;;
        codex-extra*) bad "codex dir exposes: $l" ;;
      esac
    done <"$W/bin/probe"
  fi
  if grep -qx workdir-writable "$W/bin/probe"; then ok 'work dir writable'; else bad 'work dir not writable'; fi
  if grep -qx auth-visible "$W/bin/probe"; then ok 'codex dir/auth.json visible'; else bad 'codex dir/auth.json not visible'; fi
  grep -q codex-extra "$W/bin/probe" || ok 'codex dir history, config and hooks absent'
  grep -qx common-writable "$W/bin/probe" || grep -qx common-unknown "$W/bin/probe" || ok 'git common dir not writable'
  grep -q present "$W/bin/probe" || ok 'secret and daemon paths absent'
  grep -qx worktree-writable "$W/bin/probe" || ok 'worktree read-only'
  extra=$(grep -vxE 'HOME|TMPDIR|PATH|LANG|TERM|SSL_CERT_FILE|NIX_REMOTE|NIX_CONFIG|PWD|OLDPWD|SHLVL|_' "$W/bin/envnames")
  if [ -z "$extra" ]; then ok 'environment only listed variables'; else bad "unexpected env names: $extra"; fi
  reset
  PATH="$W/bin:$PATH" bash "$script" codex "$W" -- exec -o "$W/out.md" >/dev/null 2>&1 </dev/null
  rc=$?
  if [ $rc -eq 0 ] && [ -e "$W/bin/ran" ]; then ok '-o inside work dir accepted'; else bad "-o inside work dir accepted (rc=$rc)"; fi
  reset
  GIT_WORK_TREE=$HOME PATH="$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null
  rc=$?
  if [ $rc -eq 0 ] && [ -e "$W/bin/ran" ] && ! grep -qE 'present|worktree-writable|common-|codex-extra' "$W/bin/probe"; then
    ok 'GIT_WORK_TREE=HOME does not change the result'
  else bad "GIT_WORK_TREE=HOME changed the result (rc=$rc)"; fi
  if [ -e "$HOME/.ssh" ]; then
    reset
    XDG_RUNTIME_DIR=$HOME PATH="$W/bin:$PATH" bash "$script" codex "$W" -- exec >/dev/null 2>&1 </dev/null
    if [ -e "$W/bin/ran" ] && ! grep -q "present $HOME/.ssh" "$W/bin/probe"; then
      ok 'XDG_RUNTIME_DIR=HOME does not expose ~/.ssh'
    else bad 'XDG_RUNTIME_DIR=HOME exposes ~/.ssh'; fi
  else
    skip 'XDG_RUNTIME_DIR check: no ~/.ssh on this host'
  fi
fi

if [ $fail -ne 0 ]; then
  echo FAILURES
  exit 1
fi
if [ $skipped -ne 0 ]; then
  echo 'INCOMPLETE: a check was skipped'
  exit 77
fi
echo 'ALL PASSED'
