# shellcheck shell=bash
# #2757's sandbox: what both tools get. agent-sandbox.sh gives each name its own value.
# shellcheck disable=SC2034  # read by agent-review.test.sh and agent-implement.test.sh
agent_env_base=(PATH HOME LANG TERM TMPDIR SSL_CERT_FILE NIX_REMOTE NIX_CONFIG)
# #2757's per-tool markers: CODEX_CODER for codex; AGY_CODER, AGY_WORKTREE, AGY_GUARD_LOG for agy.
agent_env_markers=(CODEX_CODER AGY_CODER AGY_WORKTREE AGY_GUARD_LOG)
# What a herdr pane or agent-env passes on from its caller (#2762). Not NIX_CONFIG or NIX_REMOTE: the
# sandbox sets its own, and a login shell's NIX_CONFIG carries the GitHub access token.
agent_env_names=(PATH HOME LANG TERM TMPDIR SSL_CERT_FILE "${agent_env_markers[@]}" XDG_RUNTIME_DIR
  XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME USER LOGNAME SHELL AGY_IMPLEMENT_PROBING)
# Prints, NUL-separated, each name on agent_env_names that the caller exported.
agent_env_exported() {
  local -A exported=()
  local entry name
  while IFS= read -r -d '' entry; do exported[${entry%%=*}]=1; done < <(env -0)
  for name in "${agent_env_names[@]}"; do
    if [[ -n ${exported[$name]:-} ]]; then printf '%s\0' "$name"; fi
  done
}
