# shellcheck shell=bash
# PreToolUse guard for coding agents (#2079, #2081). The coder edits files and
# runs checks; deploys, activation, store GC, power, service state and git
# history stay with the main session. Exit 2 denies and hands the reason back.
#
# Splits the command into the simple commands that would run, strips wrappers
# (sudo, env, timeout, bash -c, path prefixes) and judges each by its verb, so
# `rg 'git push' docs/` passes and `sudo -n /run/current-system/sw/bin/reboot`
# does not. ponytail: best-effort tripwire, not a sandbox -- `g=git; $g push`
# or a script the coder writes and runs still gets through.

cmd="$(@jq@ -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] || exit 0

block() {
  echo "BLOCKED by the coder guard (#2079, #2081): $1" >&2
  echo "This session edits files and runs checks only. Hand this step back." >&2
  exit 2
}

set -f
segments="$(printf '%s\n' "$cmd" \
  | sed -E 's/(^|[[:space:]])(bash|sh|zsh)[[:space:]]+-[a-z]*c[[:space:]]+/\n/g; s/(\$\(|[;&|()`{}]|\n)+/\n/g; s/["'\'']//g')"

while IFS= read -r seg; do
  # shellcheck disable=SC2086
  set -- $seg
  # Drop wrappers, their options and VAR=value prefixes.
  while [ $# -gt 0 ]; do
    case "$1" in
      sudo | doas | env | nice | nohup | exec | command | time | builtin) shift ;;
      timeout)
        shift
        [ $# -gt 0 ] && shift
        ;;
      -* | *=*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || continue
  base="${1##*/}"
  shift

  # First non-option word after the verb, skipping options that take a value.
  sub=""
  for a in "$@"; do
    case "$a" in -*) continue ;; esac
    sub="$a"
    break
  done

  case "$base" in
    nixos-rebuild | switch-to-configuration | nhs | activate | nix-collect-garbage)
      block "$base activates a system or collects garbage"
      ;;
    reboot | poweroff | shutdown | halt | kexec)
      block "$base changes the machine's power state"
      ;;
    nh) [ "$sub" = os ] && block "nh os activates a system" ;;
    nix-store)
      case " $* " in *" --gc "* | *" --optimise "* | *" --delete "*) block "nix-store GC" ;; esac
      ;;
    nix)
      [ "$sub" = store ] && case " $* " in *" gc "* | *" optimise "* | *" delete "*) block "nix store GC" ;; esac
      ;;
    nix-env)
      case " $* " in *profiles/system*) block "nix-env on the system profile" ;; esac
      ;;
    just)
      # Skip `--justfile X` / `-f X` / `-d X`, then judge the recipe name.
      recipe=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --justfile | -f | --working-directory | -d)
            shift
            [ $# -gt 0 ] && shift
            ;;
          -*) shift ;;
          *)
            recipe="$1"
            break
            ;;
        esac
      done
      case "$recipe" in
        *deploy* | p620 | p510 | razer | nhs) block "just $recipe deploys a host" ;;
      esac
      ;;
    systemctl)
      case "$sub" in
        start | stop | restart | try-restart | reload-or-restart | try-reload-or-restart | \
          isolate | kill | reboot | poweroff | halt | kexec | suspend | hibernate)
          block "systemctl $sub changes service or machine state"
          ;;
        enable | disable | mask)
          case " $* " in *" --now "*) block "systemctl $sub --now starts or stops a service" ;; esac
          ;;
      esac
      ;;
    git)
      # Skip global options, including the ones that take a value.
      while [ $# -gt 0 ]; do
        case "$1" in
          -C | -c | --git-dir | --work-tree | --namespace)
            shift
            [ $# -gt 0 ] && shift
            ;;
          -*) shift ;;
          *) break ;;
        esac
      done
      verb="${1:-}"
      [ $# -gt 0 ] && shift
      case "$verb" in
        commit | push | checkout | switch | rebase | merge | cherry-pick | revert | am | \
          update-ref | restore | clean | reset)
          block "git $verb changes history or discards work"
          ;;
        stash)
          case "${1:-}" in list | show) ;; *) block "git stash changes the working tree" ;; esac
          ;;
        branch)
          case " $* " in *" -D "* | *" -d "* | *" --delete "* | *" -f "* | *" --force "* | *" -m "* | *" -M "*)
            block "git branch deletes or moves a branch"
            ;;
          esac
          ;;
      esac
      ;;
  esac
done <<<"$segments"
exit 0
