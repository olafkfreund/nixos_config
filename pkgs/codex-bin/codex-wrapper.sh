#!@shell@
# shellcheck shell=sh disable=SC1008,SC2239
# `codex exec 'prompt'` also reads stdin when it is not a terminal and waits for
# EOF, so an open pipe hangs it forever (openai/codex#20919). Give it /dev/null
# unless the caller opts in with CODEX_EXEC_STDIN or passes `-`.
#
# shortcut: the value-taking option lists below are copied from `codex --help`
# 0.164.0; add any new one by hand. Delete this guard when #20919 is fixed.
real=@real@

skip='' sub='' pos=''
for a; do
  if [ -n "$skip" ]; then
    skip=''
    continue
  fi
  if [ -z "$sub" ]; then
    case $a in
      -c | --config | --enable | --disable | --remote | --remote-auth-token-env | -i | --image | -m | --model | --local-provider | -p | --profile | -s | --sandbox | -C | --cd | --add-dir | -a | --ask-for-approval) skip=1 ;;
      -*) ;;
      *)
        sub=$a
        case $sub in exec | e) ;; *) break ;; esac
        ;;
    esac
  else
    case $a in
      -c | --config | --enable | --disable | --remote | --remote-auth-token-env | -i | --image | -m | --model | --local-provider | -p | --profile | -s | --sandbox | -C | --cd | --add-dir | -a | --ask-for-approval | --thread-source | --cyber-access-program | --output-schema | --color | -o | --output-last-message) skip=1 ;;
      -)
        pos=-
        break
        ;;
      -* | resume | fork | review | help) ;;
      *)
        pos=$a
        break
        ;;
    esac
  fi
done

if [ -n "$pos" ] && [ "$pos" != - ] && [ ! -t 0 ] && [ -z "${CODEX_EXEC_STDIN-}" ]; then
  if [ -p /dev/stdin ] || [ -S /dev/stdin ]; then
    echo 'codex: stdin is not a terminal and was not read; set CODEX_EXEC_STDIN=1 to append it (openai/codex#20919)' >&2
  fi
  exec "$real" "$@" </dev/null
fi
exec "$real" "$@"
