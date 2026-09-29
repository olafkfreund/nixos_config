# shellcheck shell=bash
# PreToolUse hook adapter for agy (#2087). agy's hook payload differs from
# Claude Code's: the command lives at .toolCall.args.CommandLine, not
# .tool_input.command, and a hook must always print exactly one JSON object
# or agy rejects the reply. This adapter translates the payload and hands it
# to the shared coder guard unchanged. The install path is an absolute
# /etc path (not a Nix store path) because hooks.json is carried by
# Syncthing, which cannot follow a store symlink across hosts.
#
# Deny by default (#2087 review): the shared guard only understands shell
# commands, so every agy tool that is not one of the safe read/edit tools
# below is denied outright, and run_command is denied unless its
# CommandLine is actually a string -- an unrecognised tool name, a missing
# CommandLine or a malformed payload all fail closed rather than falling
# through to an allow.

payload="$(cat)"

if [ "${AGY_CODER:-}" != 1 ]; then
  echo '{"decision":"allow"}'
  exit 0
fi

deny() {
  # shellcheck disable=SC2016 # $r is a jq variable, not a shell one
  @jq@ -n --arg r "$1" '{decision:"deny",reason:$r}'
  exit 0
}

if ! echo "$payload" | @jq@ -e .toolCall >/dev/null 2>&1; then
  deny "unreadable hook payload"
fi

name="$(echo "$payload" | @jq@ -r '.toolCall.name // empty')"

case "$name" in
  view_file | grep_search | list_dir | find_by_name | replace_file_content | \
    multi_replace_file_content | write_to_file | ask_question | list_permissions)
    echo '{"decision":"allow"}'
    exit 0
    ;;
  run_command)
    if ! echo "$payload" | @jq@ -e '.toolCall.args.CommandLine | strings' >/dev/null 2>&1; then
      deny "run_command without a string CommandLine"
    fi
    cmd="$(echo "$payload" | @jq@ -r '.toolCall.args.CommandLine')"

    # shellcheck disable=SC2016 # $c is a jq variable, not a shell one
    msg=$(@jq@ -n --arg c "$cmd" '{tool_input:{command:$c}}' | @guard@ 2>&1 >/dev/null)
    code=$?

    if [ "$code" = 0 ]; then
      echo '{"decision":"allow"}'
    elif [ "$code" = 2 ]; then
      deny "$msg"
    else
      deny "coder guard failed (exit $code): $msg"
    fi
    ;;
  *)
    deny "tool ${name:-<missing>} is not allowed under agy-implement"
    ;;
esac
