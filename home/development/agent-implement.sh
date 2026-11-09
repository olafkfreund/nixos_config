#!/usr/bin/env bash
# shellcheck disable=SC2154 # root, common, home, safe_path, ro_paths and sink_path are set by agent-sandbox.sh and the Nix prefix
# Runs codex-implement and agy-implement inside the sandbox (#2757). Concatenated after
# agent-sandbox.sh by Nix. Neither tool is exec'd: the cleanup trap must run.
set -euo pipefail

refuse() {
  printf 'agent-implement: %s\n' "$1" >&2
  exit 2
}

tool=${1:-}
usage='usage: agent-implement <codex|agy> [--work <dir>] [--tui] -- <tool arguments>'
[[ $# -ge 2 && ($tool == codex || $tool == agy) ]] || refuse "$usage"
shift
# --work and --tui are the wrapper's own; the tool never sees them.
work='' tui=''
while (($#)) && [[ $1 != -- ]]; do
  case $1 in
    --work)
      [[ $# -ge 2 && -z $work ]] || refuse "$usage"
      work=$2
      shift
      ;;
    --tui)
      [[ -z $tui ]] || refuse "$usage"
      tui=1
      ;;
    *) refuse "$usage" ;;
  esac
  shift
done
[[ ${1:-} == -- ]] || refuse "$usage"
shift
[[ ! ${HUMANIZE_CODEX_BYPASS_SANDBOX+x} ]] || refuse 'HUMANIZE_CODEX_BYPASS_SANDBOX is set'
# An exported function or LD_* would run inside the tools the sandbox is built from.
# env -0: writeShellApplication's bash lacks the completion builtins, which made the old check a no-op (#2757).
[[ -z $(declare -Fx) ]] || refuse 'exported function, LD_* or BASH_FUNC_* in the environment'
while IFS= read -r -d '' entry; do
  case ${entry%%=*} in
    LD_* | BASH_FUNC_*) refuse 'exported function, LD_* or BASH_FUNC_* in the environment' ;;
  esac
done < <(env -0)

sandbox_repo_checks
sandbox_safe_path

# An allow-list, because a config key can change the sandbox, environment or provider.
check_config() {
  case ${1%%=*} in
    model | model_reasoning_effort) ;;
    *) refuse "config key not allowed: ${1%%=*}" ;;
  esac
}

# --work holds the pointer dirs; an output file inside it would be writable by the model.
not_in_work() {
  local p
  p=$(realpath -m -- "$1")
  [[ -z $work || ($p != "$work" && $p != "$work/"*) ]] || refuse "output file must not be inside the work dir: $1"
}

# Checks every argument before anything is created; the -o file is made afterwards.
out_file=''
set_out() {
  [[ -z $out_file ]] || refuse 'output file given twice'
  out_file=$1
}

check_codex_args() {
  if [[ -n $tui ]]; then
    [[ ${1:-} == -p && ${2:-} == implement ]] || refuse 'codex arguments must start with: -p implement'
    shift 2
  else
    [[ ${1:-} == -p && ${2:-} == implement && ${3:-} == exec ]] \
      || refuse 'codex arguments must start with: -p implement exec'
    shift 3
  fi
  local arg expect=''
  for arg in "$@"; do
    case $expect in
      config)
        check_config "$arg"
        expect=''
        continue
        ;;
      output)
        set_out "$arg"
        expect=''
        continue
        ;;
      color)
        expect=''
        continue
        ;;
    esac
    case $arg in
      --dangerously-* | --yolo* | --full-auto* | --add-dir* | -s | --sandbox | -s=* | --sandbox=* | -p | -p=* | --profile | --profile=* | --enable | --enable=* | --disable | --disable=* | --oss | --local-provider*)
        refuse "forbidden argument: $arg"
        ;;
      -c | --config) expect=config ;;
      --config=* | -c=*) check_config "${arg#*=}" ;;
      -c*) check_config "${arg#-c}" ;;
      -o | --output-last-message) expect=output ;;
      --output-last-message=*) set_out "${arg#*=}" ;;
      --color) expect=color ;;
      --color=* | --ephemeral | --json | - | --) ;;
      -*) refuse "option not allowed: $arg" ;;
      *) refuse "argument not allowed: $arg" ;;
    esac
  done
  [[ -z $expect ]] || refuse "missing value for $expect"
}

check_agy_args() {
  [[ ${1:-} == --mode && ${2:-} == accept-edits && ${3:-} == --sandbox && ${4:-} == --dangerously-skip-permissions ]] \
    || refuse 'agy arguments must start with: --mode accept-edits --sandbox --dangerously-skip-permissions'
  shift 4
  local arg expect=''
  for arg in "$@"; do
    # The prompt is free text; it is bound to -p and never read as an option.
    if [[ $expect == prompt ]]; then
      expect=''
      continue
    fi
    case $arg in
      --mode | --mode=* | --add-dir | --add-dir=* | -*gemini_dir* | -*gemini-dir* | -*config*dir* | -*config_override*)
        refuse "forbidden argument: $arg"
        ;;
    esac
    if [[ -n $expect ]]; then
      [[ $arg != -* ]] || refuse "option value must not start with '-': $arg"
      expect=''
      continue
    fi
    case $arg in
      --model | --effort | --output-format | --print-timeout) expect=value ;;
      --model=* | --effort=* | --output-format=* | --print-timeout=*) ;;
      -p) expect=prompt ;;
      *) refuse "argument not allowed: $arg" ;;
    esac
  done
  [[ -z $expect ]] || refuse 'missing option value'
}

tmp=$(mktemp -d /tmp/agent-implement.XXXXXX)
made=()
trap 'rm -rf -- "$tmp"; for d in "${made[@]}"; do rmdir -- "$d" 2>/dev/null || true; done' EXIT

# The worktree is writable, so a planted $root/.codex or $root/.gemini would configure the next run.
# A missing one gets an empty mountpoint for the read-only bind and is removed again on exit.
protect_project_dirs() {
  local d
  for d in "$root/.codex" "$root/.gemini"; do
    [[ ! -L $d && (! -e $d || -d $d) ]] || refuse "not a plain directory: $d"
    [[ -d $d ]] || {
      mkdir -- "$d"
      made+=("$d")
    }
  done
}

run_codex() {
  local config cfg=()
  check_codex_args "$@"
  [[ -z $work ]] || sandbox_team_dirs "$work"
  [[ -z $out_file ]] || not_in_work "$out_file"
  protect_project_dirs
  config=$(realpath -e -- "$home/.codex/implement.config.toml") || refuse 'missing ~/.codex/implement.config.toml'
  local binds=()
  if [[ -n $out_file ]]; then
    sandbox_check_out_file "$out_file"
    binds=(--bind "$out_file" "$out_file")
  fi
  [[ -z $work ]] || binds+=(--ro-bind "$work/req" /run/herdr-team/req --bind "$work/turns" /run/herdr-team/turns)
  [[ -z $tui ]] || cfg=(-c 'approval_policy="never"' -c "notify=[\"$sink_path\"]")
  sandbox_exec_bwrap --bind "$root" "$root" --ro-bind "$common" "$common" --bind "$tmp" "$tmp" \
    --ro-bind "$root/.codex" "$root/.codex" --ro-bind "$root/.gemini" "$root/.gemini" \
    --chdir "$root" --setenv TMPDIR "$tmp" --setenv CODEX_CODER 1 \
    --dir "$home/.codex" --bind "$home/.codex/auth.json" "$home/.codex/auth.json" \
    --ro-bind "$config" "$home/.codex/implement.config.toml" "${binds[@]}" \
    -- codex -c forced_login_method=chatgpt -c 'mcp_servers={}' "${cfg[@]}" "$@"
}

run_agy() {
  local gemini=$home/.gemini rel log='' policy=()
  check_agy_args "$@"
  [[ -z $work ]] || sandbox_team_dirs "$work"
  [[ -z ${AGY_GUARD_LOG:-} ]] || not_in_work "$AGY_GUARD_LOG"
  protect_project_dirs
  # What configures agy or runs code stays read-only; antigravity-cli/bin must stay writable.
  # A trailing slash marks a directory the sandbox creates empty when it is missing.
  local ro=(config/ hooks/ commands/ extensions/ agents/ antigravity/skills/ antigravity/bin/
    antigravity-cli/lib/ antigravity-cli/plugins/ antigravity-cli/mcp/ antigravity-cli/builtin/
    settings.json GEMINI.md AGENTS.md antigravity/user_settings.pb
    antigravity-cli/settings.json)
  for rel in "${ro[@]}"; do policy+=(--sub-ro "$gemini/$rel"); done
  # agy reads config/mcp_config.json; antigravity/mcp_config.json is a symlink to it.
  printf '{"mcpServers":{}}\n' >"$tmp/mcp-mask.json"
  for rel in config/mcp_config.json antigravity/mcp_config.json; do
    policy+=(--sub-mask "$gemini/$rel=$tmp/mcp-mask.json")
  done
  policy+=(--sub-ro "$root/.codex" --sub-ro "$root/.gemini")
  policy+=(--sub-tmpfs "$gemini/antigravity-browser-profile" --sub-tmpfs "$gemini/antigravity-backup")
  [[ -z $work ]] || policy+=(--ro-to "$work/req" /run/herdr-team/req --rw-to "$work/turns" /run/herdr-team/turns)
  policy+=(--env AGY_CODER=1 --env "AGY_WORKTREE=$root")
  if [[ -n ${AGY_GUARD_LOG:-} ]]; then
    log=$AGY_GUARD_LOG
    sandbox_check_out_file "$log"
    policy+=(--file "$log" --env "AGY_GUARD_LOG=$log")
  fi
  sandbox_exec_unshare --rw "$root" --ro "$common" --rw "$tmp" --rw "$gemini" \
    --chdir "$root" --env "TMPDIR=$tmp" "${policy[@]}" -- agy "$@"
}

rc=0
if [[ $tool == codex ]]; then
  run_codex "$@" || rc=$?
else
  run_agy "$@" || rc=$?
fi
exit "$rc"
