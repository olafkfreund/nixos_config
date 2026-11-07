#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
# Run by hand from a worktree: bash home/development/agent-implement.test.sh < /dev/null
# Not part of checkPhase: the sandbox cases need user namespaces and a nix-store write (two tiny
# fake tools). No login, no real codex or agy, and ~/.codex and ~/.gemini are fakes under a test HOME.
# Exit 1 on any mismatch, 77 if a check could not run (SKIP, never a pass). Never prints environment values.
# AGENT_IMPLEMENT=<path> tests another copy of the wrapper (mutation checks).
here=$(cd "$(dirname "$0")" && pwd)
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1
w=$(mktemp -d /tmp/agent-implement-test.XXXXXX)
trap 'rm -rf "$w"' EXIT
[[ -n ${AGENT_IMPLEMENT:-} ]] || cat "$here/agent-sandbox.sh" "$here/agent-implement.sh" >"$w/agent-implement"
script=${AGENT_IMPLEMENT:-$w/agent-implement}

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

# PATH made of store directories only: /tmp and /run are hidden inside the sandbox.
tooldirs=''
for t in unshare mount umount bash env mkdir ln cp readlink id git realpath dirname stat mktemp rm touch cut sort ls cat find grep rmdir bwrap; do
  p=$(type -ap "$t" 2>/dev/null | grep -v '^/run/wrappers' | head -1)
  [[ -n $p ]] || continue
  d=$(dirname -- "$(readlink -f -- "$p")")
  [[ -x $d/$t ]] || continue
  [[ :$tooldirs: == *":$d:"* ]] || tooldirs+=${tooldirs:+:}$d
done

# The fake tools: static, so one store path serves every run.
mkdir -p "$w/fk/fakebin"
cat >"$w/fk/fakebin/codex" <<'FAKE'
#!/usr/bin/env bash
# fd 3 is the glob's own directory handle, fd 255 the script itself.
fds=(/proc/$$/fd/*)
t=${0##*/}
o=$PWD/.out-$t
: >"$o.ran"
printf '%s\n' "$@" >"$o.args"
env | cut -d= -f1 | sort >"$o.env"
bash -lc 'env | cut -d= -f1 | sort' >"$o.lenv" 2>/dev/null </dev/null
for f in "${fds[@]}"; do n=${f##*/}; [ "$n" -gt 2 ] 2>/dev/null \
  && [ "$n" != 255 ] && [ "$n" != 3 ] && echo "fd $n"; done >"$o.fds"
prev=
for a in "$@"; do
  [ "$prev" = -o ] && echo hi >"$a"
  prev=$a
done
{
  for p in /run/agenix /var/lib /root /boot /sys/class /dev/sda /dev/nvme0n1 /dev/dri /dev/snd /run/user /run/wrappers "$HOME/.ssh"; do
    [ -e "$p" ] && { [ ! -d "$p" ] || [ -n "$(ls -A "$p")" ]; } && echo "present $p"
  done
  [ -n "$(ls -A /nix/var/nix/daemon-socket 2>/dev/null)" ] && echo "present daemon-socket"
  [ -n "$(ls -A /sys 2>/dev/null)" ] && echo "present sys"
  for f in /dev/*; do
    case ${f##*/} in null | zero | full | random | urandom | tty | pts | shm | ptmx | fd | stdin | stdout | stderr | core) ;; *) echo "present dev-${f##*/}" ;; esac
  done
  for f in "$HOME"/* "$HOME"/.[!.]*; do [ -e "$f" ] && echo "home-entry ${f##*/}"; done
  ( : >"$PWD/.wtest" ) 2>/dev/null && echo worktree-writable
  rm -f "$PWD/.wtest"
  c=$(realpath "$(git rev-parse --git-common-dir)" 2>/dev/null)
  if [ -z "$c" ]; then echo common-unknown; elif ( : >"$c/.wtest" ) 2>/dev/null; then echo common-writable; fi
  ( : >"$TMPDIR/.t" ) 2>/dev/null && echo tmp-writable
  [ -r "$HOME/.codex/auth.json" ] && echo codex-auth-visible
  ( : >>"$HOME/.codex/implement.config.toml" ) 2>/dev/null && echo codex-config-writable
  if [ -d "$HOME/.gemini" ]; then
    g=$HOME/.gemini
    for r in config/x hooks/x commands/x antigravity/skills/x antigravity-cli/lib/x antigravity-cli/plugins/x settings.json GEMINI.md antigravity-cli/settings.json; do
      ( : >>"$g/$r" ) 2>/dev/null && echo "gemini-writable $r"
    done
    ( : >"$g/antigravity-cli/bin/x" ) 2>/dev/null && echo gemini-bin-writable
    [ "$(cat "$g/config/mcp_config.json" 2>/dev/null)" = '{"mcpServers":{}}' ] && echo mcp-masked
    [ "$(cat "$g/antigravity/mcp_config.json" 2>/dev/null)" = '{"mcpServers":{}}' ] && echo mcp-masked-link
    [ -n "$(ls -A "$g/antigravity-browser-profile" 2>/dev/null)" ] && echo browser-profile-visible
  fi
  [ -n "${AGY_GUARD_LOG:-}" ] && ( : >>"$AGY_GUARD_LOG" ) 2>/dev/null && echo guardlog-writable
  for pd in .codex .gemini; do
    [ -d "$PWD/$pd" ] && ( : >"$PWD/$pd/x" ) 2>/dev/null && echo "project-dir-writable $pd"
  done
  [ -r "$PWD/.gemini/GEMINI.md" ] && echo gemini-tracked-readable
  umount /home 2>/dev/null && echo umount-worked
  unshare -Urm umount /home 2>/dev/null && echo umount-nested-worked
  [ -n "$(ls -A /home 2>/dev/null)" ] && echo home-uncovered
  echo probe-done
} >"$o.probe" 2>&1
exit 0
FAKE
cp "$w/fk/fakebin/codex" "$w/fk/fakebin/agy"
chmod +x "$w/fk/fakebin/codex" "$w/fk/fakebin/agy"

# Fake login state under a test HOME.
fh=$w/home
mkdir -p "$fh/.codex" "$fh/.ssh"
echo x >"$fh/.codex/auth.json"
echo x >"$fh/.codex/implement.config.toml"
echo x >"$fh/.codex/history.jsonl"
echo x >"$fh/.ssh/id"
g=$fh/.gemini
mkdir -p "$g/config" "$g/hooks" "$g/commands" "$g/extensions" "$g/agents" "$g/antigravity/skills" "$g/antigravity/bin" \
  "$g/antigravity-cli/lib" "$g/antigravity-cli/plugins" "$g/antigravity-cli/mcp" "$g/antigravity-cli/builtin" \
  "$g/antigravity-cli/bin" "$g/antigravity-browser-profile"
for f in settings.json settings.nix settings.json.orig GEMINI.md AGENTS.md antigravity/user_settings.pb antigravity-cli/settings.json antigravity-browser-profile/cookie; do
  echo x >"$g/$f"
done
echo '{"mcpServers":{"evil":{}}}' >"$g/config/mcp_config.json"
ln -s ../config/mcp_config.json "$g/antigravity/mcp_config.json"

repo=$w/repo
git init -q "$repo"
mkdir -p "$w/outdir" "$repo/.gemini"
echo tracked >"$repo/.gemini/GEMINI.md"

# runi <args…>: the wrapper from the test repo, test HOME, a caller sentinel and an open fd 9.
XENV=()
FAKEDIR=''
runi() {
  rm -f "$repo"/.out-*
  (
    cd "$repo" || exit 1
    exec 9>"$w/leakfd"
    env -u AGY_GUARD_LOG TESTSENTINEL=1 HOME="$fh" PATH="${FAKEDIR:+$FAKEDIR:}$tooldirs" "${XENV[@]}" bash "$script" "$@"
  ) >"$w/last.out" 2>&1 </dev/null
}
# refused <label> <args…>: exit 2 and no tool started.
refused() {
  local label=$1 rc
  shift
  runi "$@"
  rc=$?
  if [ $rc -eq 2 ] && ! ls "$repo"/.out-*.ran >/dev/null 2>&1; then ok "$label"; else bad "$label (rc=$rc)"; fi
}

CX=(codex -- -p implement exec)
AG=(agy -- --mode accept-edits --sandbox --dangerously-skip-permissions)

refused 'usage: no tool' foo -- x
refused 'usage: no --' codex exec
refused 'codex: no -p implement' codex -- exec -
refused 'codex: other profile' codex -- -p other exec -
refused 'codex: not exec' codex -- -p implement mcp
refused 'codex: review subcommand' codex -- -p implement review
for a in --dangerously-bypass-approvals-and-sandbox --yolo --full-auto --add-dir=x --oss --search -a; do
  refused "codex: $a" "${CX[@]}" "$a" -
done
refused 'codex: -s' "${CX[@]}" -s read-only -
refused 'codex: --sandbox=' "${CX[@]}" --sandbox=read-only -
refused 'codex: second -p' "${CX[@]}" -p other -
refused 'codex: --profile' "${CX[@]}" --profile other -
refused 'codex: --enable' "${CX[@]}" --enable x -
refused 'codex: positional' "${CX[@]}" some-prompt
for k in sandbox_mode mcp_servers model_provider approval_policy review_model; do
  refused "codex: -c $k" "${CX[@]}" -c "$k=v" -
  refused "codex: -c$k" "${CX[@]}" "-c$k=v" -
  refused "codex: --config=$k" "${CX[@]}" "--config=$k=v" -
done
refused 'agy: no preamble' agy -- --model x
refused 'agy: preamble out of order' agy -- --sandbox --mode accept-edits --dangerously-skip-permissions
refused 'agy: second --mode' "${AG[@]}" --mode plan
refused 'agy: --add-dir' "${AG[@]}" --add-dir /x
refused 'agy: --gemini-dir' "${AG[@]}" --gemini-dir=/x
refused 'agy: config dir' "${AG[@]}" --config-dir /x
refused 'agy: config override' "${AG[@]}" --config_override=x
refused 'agy: unknown option' "${AG[@]}" --some-future-flag
refused 'agy: model value that looks like --add-dir' "${AG[@]}" --model --add-dir
XENV=(HUMANIZE_CODEX_BYPASS_SANDBOX=1)
refused 'HUMANIZE_CODEX_BYPASS_SANDBOX' "${CX[@]}" -
XENV=('BASH_FUNC_mount%%=() { :; }')
refused 'BASH_FUNC_mount%% in the environment' "${CX[@]}" -
refused 'BASH_FUNC_mount%% in the environment (agy)' "${AG[@]}" -p hi
XENV=(LD_PRELOAD=/nonexistent.so)
refused 'LD_PRELOAD in the environment' "${CX[@]}" -
XENV=()
refused 'agy: --model value starting with -' "${AG[@]}" --model --no-sandbox
refused 'agy: --effort value starting with -' "${AG[@]}" --effort -x

# Rejected -o and AGY_GUARD_LOG paths.
ln -s "$w/outdir/real" "$w/outdir/sl"
ln -s "$w/outdir" "$w/plink"
: >"$w/outdir/exists"
ln "$w/outdir/exists" "$w/outdir/hard"
echo x >"$repo/inrepo"
edir=$(mktemp -d "$HOME/.agent-impl-test.XXXXXX")
bad_paths=("$w/outdir/sl" "$w/plink/x" "$w/outdir/hard" "$w/outdir/exists" "/tmp/agent-impl-test-$$"
  "$repo/out" "$fh/.gemini/out" "$fh/.codex/out" "/etc/agent-impl-test" "relative/out"
  "$HOME/agent-impl-test-$$" "$edir/out")
labels=(symlink 'symlinked parent' 'hard link' 'existing file' 'root-owned parent' 'inside the worktree' 'inside ~/.gemini' 'inside ~/.codex' 'inside /etc' 'relative path' 'real HOME itself' 'own dir outside /tmp, as ~/.config/autostart')
for i in "${!bad_paths[@]}"; do
  refused "-o rejected: ${labels[i]}" "${CX[@]}" -o "${bad_paths[i]}" -
  refused "--output-last-message= rejected: ${labels[i]}" "${CX[@]}" "--output-last-message=${bad_paths[i]}" -
  XENV=("AGY_GUARD_LOG=${bad_paths[i]}")
  refused "AGY_GUARD_LOG rejected: ${labels[i]}" "${AG[@]}"
  XENV=()
done
XENV=()
refused '-o given twice' "${CX[@]}" -o "$w/outdir/a" -o "$w/outdir/b" -
rmdir "$edir"
[ ! -e "$w/outdir/a" ] && ok 'a refused call creates no -o file' || bad 'a refused call created a -o file'

# A failing tool backend: the tool must not run, the exit must be non-zero.
mkdir -p "$w/fakebwrap" "$w/fakeunshare"
printf '#!/bin/sh\nexit 1\n' >"$w/fakebwrap/bwrap"
printf '#!/bin/sh\nexit 1\n' >"$w/fakeunshare/unshare"
chmod +x "$w/fakebwrap/bwrap" "$w/fakeunshare/unshare"

# codex-implement's guard check, extracted from codex-cli.nix.
snippet=$(sed -n '/^ *req=\/etc\/codex\/requirements.toml/,/^ *fi$/p' "$here/codex-cli.nix" | sed 's|\${pkgs.yq-go}/bin/yq|yq|')
if ! command -v yq >/dev/null || [ -z "$snippet" ]; then
  skip 'codex-implement guard check: no yq or snippet not found'
else
  touch "$w/guard"
  chmod +x "$w/guard"
  guardcheck() { # <toml file> <guard file>
    bash -c "$(printf '%s\n' "$snippet" | sed "s|^ *req=.*|req=$1|; s|^ *guard=.*|guard=$2|")" >/dev/null 2>&1
  }
  printf '[[hooks.PreToolUse]]\n[[hooks.PreToolUse.hooks]]\ntype = "command"\ncommand = "/etc/codex/hooks/coder-guard"\n' >"$w/req-good.toml"
  printf '[[hooks.PreToolUse]]\n[[hooks.PreToolUse.hooks]]\ntype = "command"\ncommand = "/bin/true"\n' >"$w/req-none.toml"
  printf '[[hooks.SubagentStop]]\n[[hooks.SubagentStop.hooks]]\ntype = "command"\ncommand = "/etc/codex/hooks/coder-guard"\n' >"$w/req-other.toml"
  printf '[hooks]\n' >"$w/req-empty.toml"
  printf 'x = = \n' >"$w/req-bad.toml"
  guardcheck "$w/req-good.toml" "$w/guard" && ok 'guard check: registered and executable' || bad 'guard check: registered and executable'
  guardcheck "$w/req-none.toml" "$w/guard" && bad 'guard check: hook absent' || ok 'guard check: hook absent refused'
  guardcheck "$w/req-other.toml" "$w/guard" && bad 'guard check: hook under SubagentStop only' || ok 'guard check: hook under SubagentStop only refused'
  guardcheck "$w/req-empty.toml" "$w/guard" && bad 'guard check: no PreToolUse table' || ok 'guard check: no PreToolUse table refused'
  guardcheck "$w/req-bad.toml" "$w/guard" && bad 'guard check: unparsable file' || ok 'guard check: unparsable file refused'
  guardcheck "$w/missing.toml" "$w/guard" && bad 'guard check: missing file' || ok 'guard check: missing file refused'
  chmod -x "$w/guard"
  guardcheck "$w/req-good.toml" "$w/guard" && bad 'guard check: guard not executable' || ok 'guard check: guard not executable refused'
fi

if ! command -v unshare >/dev/null || ! unshare --user --map-root-user true >/dev/null 2>&1 \
  || ! bwrap --ro-bind / / true >/dev/null 2>&1; then
  skip 'sandbox checks: user namespaces or bwrap unavailable'
elif ! FAKEDIR=$(nix-store --add "$w/fk/fakebin" 2>/dev/null); then
  skip 'sandbox checks: cannot add the fake tools to the nix store'
else
  # A failing backend: non-zero, the tool does not run.
  FAKEDIR_SAVE=$FAKEDIR
  FAKEDIR=$w/fakebwrap
  runi "${CX[@]}" -
  rc=$?
  if [ $rc -ne 0 ] && ! ls "$repo"/.out-*.ran >/dev/null 2>&1; then ok 'failing bwrap'; else bad "failing bwrap (rc=$rc)"; fi
  FAKEDIR=$w/fakeunshare
  runi "${AG[@]}" -p hi
  rc=$?
  if [ $rc -ne 0 ] && ! ls "$repo"/.out-*.ran >/dev/null 2>&1; then ok 'failing unshare'; else bad "failing unshare (rc=$rc)"; fi
  FAKEDIR=$FAKEDIR_SAVE

  # env -i: with the refusal removed, a planted function must not reach the namespace.
  sed '/declare -Fx/d' "$script" >"$w/noref"
  sed 's/env)" -i /env)" /' "$w/noref" >"$w/mutant"
  grep -q 'env)" -i ' "$w/noref" && ! grep -q 'env)" -i ' "$w/mutant" || bad 'mutant not built'
  planted() { # <script> <tool args…>: run with a planted mount function
    local s=$1
    shift
    script=$s
    XENV=('BASH_FUNC_mount%%=() { :; }' 'BASH_FUNC_bwrap%%=() { :; }')
    runi "$@"
    prc=$?
    XENV=()
    script=$real_script
  }
  real_script=$script
  planted "$w/noref" "${AG[@]}" -p hi
  if [ $prc -eq 0 ] && [ -e "$repo/.out-agy.ran" ] && ! grep -q '^present' "$repo/.out-agy.probe"; then ok 'env -i: planted mount function has no effect (agy)'; else bad "env -i: planted mount function acted (agy, rc=$prc)"; fi
  planted "$w/noref" "${CX[@]}" -
  if [ $prc -eq 0 ] && [ -e "$repo/.out-codex.ran" ]; then ok 'env -i: planted bwrap function has no effect (codex)'; else bad "env -i: planted bwrap function acted (codex, rc=$prc)"; fi
  planted "$w/mutant" "${AG[@]}" -p hi
  if [ $prc -ne 0 ] || [ ! -e "$repo/.out-agy.ran" ] || grep -q '^present' "$repo/.out-agy.probe"; then ok 'mutant without env -i fails (agy)'; else bad 'mutant without env -i passes (agy)'; fi

  # Shared checks on one run of a tool. <tool> <ext…>
  common_checks() {
    local tool=$1 probe="$repo/.out-$1.probe" l
    if [ -e "$repo/.out-$tool.ran" ]; then ok "$tool runs"; else
      bad "$tool did not run: $(head -c 300 "$w/last.out")"
      return
    fi
    grep -qx probe-done "$probe" && ok "$tool: probe finished" || {
      bad "$tool: probe did not finish, negative checks are void"
      return
    }
    grep -q '^project-dir-writable' "$probe" && bad "$tool: project .codex/.gemini writable" || ok "$tool: project .codex and .gemini read-only"
    grep -qx gemini-tracked-readable "$probe" && ok "$tool: tracked .gemini content readable" || bad "$tool: tracked .gemini content unreadable"
    [ ! -e "$repo/.codex" ] && ok "$tool: no .codex left on the host" || bad "$tool: .codex left on the host"
    while IFS= read -r l; do
      case $l in
        present*) bad "$tool: sandbox leaks: $l" ;;
        worktree-writable | tmp-writable) ;;
        common-writable | common-unknown) bad "$tool: git common dir: $l" ;;
        umount-worked | umount-nested-worked | home-uncovered) bad "$tool: a hidden tree was uncovered: $l" ;;
        home-entry*) ;;
      esac
    done <"$probe"
    grep -qx worktree-writable "$probe" && ok "$tool: worktree writable" || bad "$tool: worktree not writable"
    grep -qx tmp-writable "$probe" && ok "$tool: TMPDIR writable" || bad "$tool: TMPDIR not writable"
    grep -qE '^(common-writable|common-unknown)$' "$probe" || ok "$tool: git common dir read-only"
    grep -q '^present' "$probe" || ok "$tool: secrets, daemon socket, /sys and host devices absent"
    grep -qE '^(umount-worked|umount-nested-worked|home-uncovered)$' "$probe" || ok "$tool: umount cannot uncover a hidden tree"
    if grep -qx TESTSENTINEL "$repo/.out-$tool.env" || grep -qx TESTSENTINEL "$repo/.out-$tool.lenv"; then bad "$tool: caller variable leaked"; else ok "$tool: caller variables do not leak, also in a login shell"; fi
    local extra
    extra=$(grep -vxE 'HOME|TMPDIR|PATH|LANG|TERM|SSL_CERT_FILE|NIX_REMOTE|NIX_CONFIG|PWD|OLDPWD|SHLVL|_|CODEX_CODER|AGY_CODER|AGY_WORKTREE|AGY_GUARD_LOG' "$repo/.out-$tool.env")
    if [ -z "$extra" ]; then ok "$tool: environment only listed variables"; else bad "$tool: unexpected env names: $extra"; fi
    if [ -s "$repo/.out-$tool.fds" ]; then bad "$tool: extra descriptors: $(tr '\n' ' ' <"$repo/.out-$tool.fds")"; else ok "$tool: only descriptors 0-2"; fi
  }

  # codex
  runi "${CX[@]}" -c model=x -o "$w/outdir/msg" -
  rc=$?
  [ $rc -eq 0 ] && ok 'codex: allowed call exits 0' || bad "codex: allowed call exits $rc"
  common_checks codex
  p=$repo/.out-codex.probe
  grep -qx codex-auth-visible "$p" && ok 'codex: login visible' || bad 'codex: login not visible'
  grep -qx codex-config-writable "$p" && bad 'codex: implement.config.toml writable' || ok 'codex: implement.config.toml read-only'
  [ "$(grep -c '^home-entry' "$p")" -eq 1 ] && grep -qx 'home-entry .codex' "$p" && ok 'codex: only ~/.codex under HOME' || bad 'codex: HOME shows more than ~/.codex'
  grep -qx CODEX_CODER "$repo/.out-codex.env" && ok 'codex: CODEX_CODER set' || bad 'codex: CODEX_CODER missing'
  grep -qx AGY_CODER "$repo/.out-codex.env" && bad 'codex: AGY_CODER leaked in' || ok 'codex: no AGY_CODER'
  for opt in forced_login_method=chatgpt 'mcp_servers={}' model=x; do
    grep -qxF -- "$opt" "$repo/.out-codex.args" && ok "codex: arg $opt" || bad "codex: arg $opt"
  done
  [ "$(cat "$w/outdir/msg" 2>/dev/null)" = hi ] && ok 'codex: -o file written through the bind' || bad 'codex: -o file not written'

  # agy
  XENV=("AGY_GUARD_LOG=$w/outdir/guard.log")
  runi "${AG[@]}" --model m -p hi
  rc=$?
  XENV=()
  [ $rc -eq 0 ] && ok 'agy: allowed call exits 0' || bad "agy: allowed call exits $rc"
  common_checks agy
  p=$repo/.out-agy.probe
  [ "$(grep -c '^home-entry' "$p")" -eq 1 ] && grep -qx 'home-entry .gemini' "$p" && ok 'agy: only ~/.gemini under HOME' || bad 'agy: HOME shows more than ~/.gemini'
  grep -q '^gemini-writable' "$p" && bad "agy: protected ~/.gemini path writable: $(grep '^gemini-writable' "$p" | tr '\n' ' ')" || ok 'agy: protected ~/.gemini paths read-only'
  grep -qx gemini-bin-writable "$p" && ok 'agy: antigravity-cli/bin writable' || bad 'agy: antigravity-cli/bin not writable'
  grep -qx mcp-masked "$p" && grep -qx mcp-masked-link "$p" && ok 'agy: MCP config masked' || bad 'agy: MCP config not masked'
  grep -qx browser-profile-visible "$p" && bad 'agy: browser profile visible' || ok 'agy: browser profile hidden'
  grep -qx guardlog-writable "$p" && ok 'agy: AGY_GUARD_LOG writable' || bad 'agy: AGY_GUARD_LOG not writable'
  for v in AGY_CODER AGY_WORKTREE AGY_GUARD_LOG; do
    grep -qx "$v" "$repo/.out-agy.env" && ok "agy: $v set" || bad "agy: $v missing"
  done
  grep -qx CODEX_CODER "$repo/.out-agy.env" && bad 'agy: CODEX_CODER leaked in' || ok 'agy: no CODEX_CODER'
  [ "$(sed -n 1,4p "$repo/.out-agy.args" | tr '\n' ' ')" = '--mode accept-edits --sandbox --dangerously-skip-permissions ' ] \
    && ok 'agy: arguments passed through' || bad 'agy: arguments changed'
  [ "$(cat "$g/config/mcp_config.json")" = '{"mcpServers":{"evil":{}}}' ] && ok 'agy: real MCP config untouched' || bad 'agy: real MCP config changed'
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
