#!/usr/bin/env bash
set -euo pipefail

refuse() {
  printf 'agent-review: %s\n' "$1" >&2
  exit 2
}

# A caller's GIT_* could point the repo mounts at home.
for var in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_NAMESPACE GIT_PREFIX; do
  unset "$var"
done

tool=${1:-}
[[ $tool != agy ]] || refuse 'agy is not yet supported (#2748)'
[[ $tool == codex && $# -ge 3 && $3 == -- ]] || refuse 'usage: agent-review codex <work-dir> -- <tool arguments>'
[[ ! ${HUMANIZE_CODEX_BYPASS_SANDBOX+x} ]] || refuse 'HUMANIZE_CODEX_BYPASS_SANDBOX is set'

[[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]] || refuse 'current directory is not a git worktree'
root=$(realpath -e -- "$(git rev-parse --show-toplevel)")
common=$(realpath -e -- "$(git rev-parse --git-common-dir)")
home=$(realpath -e -- "$HOME")
for path in "$root" "$common"; do
  [[ $path != "$home" && $home != "$path/"* && $path != / ]] || refuse 'repo must not contain the home directory'
done

work_dir=$2
[[ -d $work_dir && ! -L $work_dir ]] || refuse 'work dir must be an existing real directory'
work_dir=$(realpath -e -- "$work_dir") || refuse 'work dir cannot be resolved'
# A lexical comparison also rejects symlinks in parent path components.
[[ $(realpath -m -s -- "$2") == "$work_dir" ]] || refuse 'work dir must not use symlinks'

# Only /tmp: XDG_RUNTIME_DIR comes from the caller and holds live sockets.
[[ $work_dir == /tmp/* ]] || refuse 'work dir must be under /tmp'
[[ -O $work_dir ]] || refuse 'work dir must be owned by the caller'
sockets=$(find "$work_dir" -type s -print -quit) || refuse 'work dir cannot be searched'
[[ -z $sockets ]] || refuse 'work dir must not contain sockets'

for protected in "$root" "$common" "$home/.codex" "$home/.gemini"; do
  protected=$(realpath -m -- "$protected")
  [[ $work_dir != "$protected" && $work_dir != "$protected/"* && $protected != "$work_dir/"* ]] \
    || refuse 'work dir overlaps a protected path'
done

shift 3
# Other subcommands (mcp, login, sandbox) can change ~/.codex, which stays writable.
[[ ${1:-} == exec || ${1:-} == review ]] || refuse 'only codex exec and codex review are allowed'

# -o is written by the parent, outside Codex's read-only sandbox.
check_output() {
  [[ $(realpath -m -- "$1") == "$work_dir/"* ]] || refuse 'output file must be inside the work dir'
}

# An allow-list, because a config key can change the sandbox, environment or provider.
check_config() {
  case ${1%%=*} in
    model | model_reasoning_effort | review_model) ;;
    *) refuse "config key not allowed: ${1%%=*}" ;;
  esac
}

expect=''
for arg in "$@"; do
  case $arg in
    --dangerously-* | --yolo | --yolo=* | --full-auto | --full-auto=* | --add-dir | --add-dir=* | --settings | --settings=* | --mode | --mode=* | --model | --model=* | -p | -p=* | --profile | --profile=* | --enable | --enable=* | --disable | --disable=* | --oss | --local-provider | --local-provider=* | --sandbox-state* | -*gemini_dir* | -*gemini-dir* | -*config*dir* | -*config_override*)
      refuse "forbidden argument: $arg"
      ;;
  esac
  case $expect in
    sandbox)
      [[ $arg == read-only ]] || refuse 'sandbox must be read-only'
      expect=''
      continue
      ;;
    config)
      check_config "$arg"
      expect=''
      continue
      ;;
    output)
      check_output "$arg"
      expect=''
      continue
      ;;
  esac

  case $arg in
    -s | --sandbox) expect=sandbox ;;
    --sandbox=* | -s=*) [[ ${arg#*=} == read-only ]] || refuse 'sandbox must be read-only' ;;
    -c | --config) expect=config ;;
    --config=* | -c=*) check_config "${arg#*=}" ;;
    -c*) check_config "${arg#-c}" ;;
    # Default-deny: an option Codex adds later, or an attached value like -sfoo, stays out.
    - | --) ;;
    --output-last-message) expect=output ;;
    --output-last-message=*) check_output "${arg#*=}" ;;
    --*)
      case ${arg%%=*} in
        --ephemeral | --skip-git-repo-check | --json | --color | --output-schema | --cd | --image | --base | --uncommitted | --commit | --title) ;;
        *) refuse "option not allowed: ${arg%%=*}" ;;
      esac
      ;;
    -o) expect=output ;;
    -C | -i) ;;
    -*) refuse "option not allowed: $arg" ;;
    sandbox_mode=* | sandbox_permissions=* | approval_policy=* | mcp_servers=*) refuse 'protected Codex config' ;;
  esac
done
[[ -z $expect ]] || refuse "missing value for $expect"

mounts=()
for path in /nix /etc /usr /bin /lib /lib64 /run/current-system /run/systemd/resolve /run/nscd; do
  [[ ! -e $path ]] || mounts+=(--ro-bind "$path" "$path")
done

# A relative PATH entry, or one inside the reviewed repo, would find a codex planted there,
# and it would run as the parent, outside Codex's own sandbox.
safe_path=
IFS=: read -ra entries <<<"${PATH:-}"
for entry in "${entries[@]}"; do
  case $entry in
    /*) ;;
    *) continue ;;
  esac
  # Compare the resolved path, so `/./`, `..` and symlinks cannot reach into the repo.
  real=$(realpath -e -- "$entry" 2>/dev/null) || continue
  case $real/ in
    "$root"/* | "$common"/*) continue ;;
  esac
  safe_path+=${safe_path:+:}$entry
done

exec bwrap "${mounts[@]}" \
  --tmpfs /nix/var/nix/daemon-socket \
  --dev /dev --proc /proc --tmpfs /tmp --tmpfs /home \
  --unshare-pid --unshare-ipc --die-with-parent \
  --ro-bind "$root" "$root" --ro-bind "$common" "$common" \
  --bind "$work_dir" "$work_dir" --chdir "$root" \
  --clearenv \
  --setenv HOME "$home" --setenv TMPDIR "$work_dir" \
  --setenv PATH "$safe_path" --setenv LANG "${LANG:-}" \
  --setenv TERM "${TERM:-dumb}" --setenv SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
  --setenv NIX_REMOTE 'local?read-only=true' \
  --setenv NIX_CONFIG 'experimental-features = nix-command flakes read-only-local-store' \
  --dir "$home/.codex" --bind "$home/.codex/auth.json" "$home/.codex/auth.json" \
  -- codex -c forced_login_method=chatgpt -c 'mcp_servers={}' -c 'sandbox_mode="read-only"' "$@"
