#!/usr/bin/env bash
# shellcheck disable=SC2154 # root, common, home, safe_path and sink_path are set by agent-sandbox.sh and the Nix prefix
set -euo pipefail

refuse() {
  printf 'agent-review: %s\n' "$1" >&2
  exit 2
}

tool=${1:-}
[[ $tool != agy ]] || refuse 'agy is not yet supported (#2748)'
[[ $tool == codex && $# -ge 3 && ($3 == -- || $3 == --tui) ]] || refuse 'usage: agent-review codex <work-dir> (--tui [-c model=…] | -- <tool arguments>)'
tui=''
[[ $3 != --tui ]] || tui=1
[[ ! ${HUMANIZE_CODEX_BYPASS_SANDBOX+x} ]] || refuse 'HUMANIZE_CODEX_BYPASS_SANDBOX is set'

sandbox_repo_checks

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
# Interactive Codex for a herdr pane: only the pointer dirs are bound, never the work dir itself.
if [[ -n $tui ]]; then
  tui_cfg=()
  while (($#)); do
    [[ $1 == -c && $# -ge 2 ]] || refuse 'with --tui only -c model=… and -c model_reasoning_effort=… are allowed'
    case $2 in
      model=* | model_reasoning_effort=*) tui_cfg+=(-c "$2") ;;
      *) refuse "config key not allowed: ${2%%=*}" ;;
    esac
    shift 2
  done
  sandbox_team_dirs "$work_dir"
  sandbox_safe_path
  rc=0
  sandbox_exec_bwrap --ro-bind "$root" "$root" --ro-bind "$common" "$common" \
    --ro-bind "$work_dir/req" /run/herdr-team/req --bind "$work_dir/turns" /run/herdr-team/turns \
    --chdir "$root" --dir "$home/.codex" --bind "$home/.codex/auth.json" "$home/.codex/auth.json" \
    -- codex -c forced_login_method=chatgpt -c 'mcp_servers={}' -c 'sandbox_mode="read-only"' \
    -c 'approval_policy="never"' -c "notify=[\"$sink_path\"]" "${tui_cfg[@]}" || rc=$?
  exit "$rc"
fi
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

sandbox_safe_path

sandbox_exec_bwrap --ro-bind "$root" "$root" --ro-bind "$common" "$common" \
  --bind "$work_dir" "$work_dir" --chdir "$root" --setenv TMPDIR "$work_dir" \
  --dir "$home/.codex" --bind "$home/.codex/auth.json" "$home/.codex/auth.json" \
  -- codex -c forced_login_method=chatgpt -c 'mcp_servers={}' -c 'sandbox_mode="read-only"' "$@"
