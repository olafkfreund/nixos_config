---
status: approved
issue: 2757
author: olafkfreund
---

# Intent: Keep secrets out of reach of codex-implement and agy-implement

Follows #2748 (`intent/2026-11-06-2748-agent-delegated-permissions.md`), which put
delegated reviews inside `agent-review`. Split out of that plan's step 10.

## Problem

`codex-implement` and `agy-implement` write code for an approved `plan/`, through
`agent-run` (`home/development/agent-run.sh`). Neither runs inside `agent-review`, and
both can read secrets that #2748 hid from reviewers. Whatever they read can go back to
their model.

How each one starts today:

- **codex-implement** (`home/development/codex-cli.nix:27`) runs
  `CODEX_CODER=1 codex -p implement`. The profile is `sandbox_mode = "workspace-write"`,
  `approval_policy = "on-request"` and `network_access = false`. The coder guard is a managed
  hook (`modules/programs/claude-code-managed.nix:331`) that judges shell commands only. The
  guard exits 0 when a call has no `.tool_input.command`. Unlike agy-implement, the
  launcher does not check that the managed hook is installed before it starts.
- **agy-implement** (`home/development/antigravity-config.nix:146`) runs
  `agy --mode accept-edits --sandbox --dangerously-skip-permissions` with the real `HOME`
  and the caller's environment. Under that flag the coder-guard adapter
  (`modules/programs/agy-guard-adapter.sh`) is the only barrier for file tools.
  It allows `view_file`, `read_file`, `grep_search`, `list_dir` and `find_by_name` on
  **any path**, as long as no string argument contains `.gemini` (lines 52 and 69). agy's terminal sandbox makes
  the workspace read-only for commands, and `nix build` still works through the daemon
  there (`spec/2026-10-14-2298-agy-sandbox-bypass.md`, section 2).

### Evidence

On p620, 2026-11-07, `codex sandbox -P :workspace -p implement` ran a script of `test -r`
checks in a throwaway git repo under `/tmp`, with no model involved. No value was printed.

| Probe | Under codex-implement's sandbox | Unsandboxed |
| ----- | ------------------------------- | ----------- |
| `/run/agenix/api-openai` | **readable** | readable |
| `~/.ssh/id_ed25519` | **readable** | readable |
| `~/.config/gh/hosts.yml` | **readable** | readable |
| agy's login, `~/.gemini/oauth_creds.json` | **readable** | readable |
| `~/.config/nix/nix.conf`, which holds `access-tokens` | **readable** | readable |
| Session bus `/run/user/1000/bus`, `/var/lib`, `/mnt`, `/home/ollama` | **readable** | readable |
| Another process's `/proc/<pid>/environ` | hidden (own PID namespace) | readable |
| Nix daemon socket | present, but `connect` is refused (`Operation not permitted`) | reachable |
| `nix eval --expr 1+1` | works | works |
| Outbound TCP | blocked | open |
| Write to `$HOME` | blocked | allowed |
| Write to the repo | allowed | allowed |

There are three more exposures that the probe does not show:

- **Environment.** The Claude Code session that calls `agent-run` holds literal tokens,
  for example `GITHUB_API_TOKEN`, `CACHIX_AUTH_TOKEN`, `OLLAMA_API_KEY` and
  `CLAUDE_CODE_MESSAGING_TOKEN`. Values were checked for shape only. Neither launcher sanitizes
  the environment. agy-implement unsets only `CASCADE_GLOBAL_CONFIG_OVERRIDE`.
  Codex's `shell_environment_policy` default may filter names that contain
  `KEY` or `TOKEN` from commands. That is not verified. agy's handling is not known.
- **Codex MCP servers.** `codex -p implement` layers its profile over `~/.codex/config.toml`,
  which lists about 30 MCP servers. Among them are `github`, `agent-bus`, `ai-mirror` (drives
  the desktop), `mcp-server-fetch` (network), `atlassian` and `mcpterm`. MCP servers run
  outside Codex's sandbox. The coder guard lets their calls through, because they carry no
  shell command. It is unverified whether headless `exec` with `on-request` runs these calls
  or refuses them. If it runs them, they bypass both the sandbox and the guard.
- **agy MCP servers.** The adapter denies every tool it does not list, so MCP calls fail
  closed. The server processes still start outside the sandbox, with the real `HOME`.

agy was not probed live. A probe would need a model session with write access, and the
code alone establishes the file-tool exposure.

### Summary

| Exposure | codex-implement | agy-implement |
| -------- | --------------- | ------------- |
| Reads agenix secrets, SSH key, gh token, other tool's login | yes, from commands | yes, from file tools |
| Nix daemon (a trusted user is root-equivalent, #2758) | refused by the sandbox | reachable from commands |
| Caller's environment tokens | maybe filtered from commands, unverified | inherited; reach to commands unknown |
| Unsandboxed MCP tools | about 30 configured; whether they run is unverified | denied by the adapter |
| Network from commands | blocked | not known |

## Proposed outcome

- Neither implementer can read `/run/agenix/*`, `~/.ssh`, `~/.config/gh`, the other tool's
  login, the session bus, `/mnt`, `/var/lib`, other users' homes, Nix `access-tokens` or other
  processes' environments, through any tool: shell, file tool or MCP.
- Neither implementer inherits a credential from the caller's environment, apart from its
  own login.
- Neither implementer can reach an MCP server that acts outside its sandbox.
- Commands keep no outbound network, and cannot connect to local sockets such as
  1Password's abstract sockets (`@1PASSWORD_MCP`, #2748 plan step 8).
- The one secret left in reach is each tool's own login, which it needs to work. The
  model could read it, as #2748 accepted for reviewers. This is written down.
- Each implementer can still write its task worktree, and nothing else that matters, and can
  still run the checks a plan step names.
- A repeatable probe, using the list from #2748 plan step 8 plus a write and a file-tool
  read, shows all of this on p620 and razer. Any exposure it does not close is written down
  in `AGENTS.md` and `docs/tooling/agy-coder-guard.md`.

## Affected users and systems

- `codex-implement` and `agy-implement`, and through them `agent-run`, `herdr-run` and the
  `handoff` and `team` skills.
- p620 and razer, where they run. p510 runs claude-code too, but implementers are not used
  there and it is not built without asking.
- Files likely touched: `home/development/codex-cli.nix`,
  `home/development/antigravity-config.nix`, `home/development/agent-review.sh` or a sibling,
  `modules/programs/agy-guard-adapter.sh`, `AGENTS.md`, the `handoff` skill and
  `docs/tooling/agy-coder-guard.md`.
- `agy-guard-probe`, which starts `agy-implement` itself, must keep passing.

## Constraints

- Implementers must edit files in their task worktree and stage new files. Staging writes
  the worktree's index under `.git/worktrees/<name>` and objects under the common `.git`.
  History must stay out of reach. The coder guard calls itself "a best-effort tripwire,
  not a sandbox" (`modules/programs/claude-coder-guard.sh:9`). So if the spec makes `.git`
  writable, it must say what still prevents a ref or history change.
- Implementers must still run the checks a plan step names: `just check-syntax`, `statix`,
  `deadnix`, shell tests, `nix eval`. With the daemon hidden, `nix build` and flake evaluation
  failed in #2748's tested setup. That is the trade-off #2748 made for reviewers. Claude would then run builds
  after the step.
- Fail closed. A launcher refuses to start if its sandbox cannot be set up. The sandbox keeps
  the variables the guards depend on: `CODEX_CODER=1`, `AGY_CODER=1` and `AGY_WORKTREE`.
  Without them, both guards allow everything. agy-implement's existing checks for the guard
  file, the hooks entry and the version probe stay. The known traps
  still apply: Codex skips untrusted hooks, and agy's payload differs from Claude Code's.
- Each tool's login must still refresh an expired token and write the cache or state it
  needs, as in #2748's acceptance checks.
- Logins stay by subscription only, never an API key (#1831). `HUMANIZE_CODEX_BYPASS_SANDBOX`
  stays forbidden. `--dangerously-skip-permissions` is passed only by `agy-implement` itself
  (#2296).
- agy's own sandbox needs user namespaces and the `/bin` remount fix from #2298. A sandbox
  wrapped around agy must not break it, and the guard probe must still pass.
- `~/.gemini` is synced by Syncthing. Nothing here writes into it as store symlinks.
- Nothing is built or deployed on p510 without asking first.

## Open questions

1. **Sandbox or document?** The issue offers either one.
   Recommendation: sandbox both. The reads are live, the model sees whatever it reads, and
   `agent-review` already does it for Codex. It refuses agy (line 15), but #2748's tests
   showed agy's login works inside the same `bwrap`.
2. **One wrapper or two?** Options: extend `agent-review` with a writable-worktree mode, or
   add a sibling. Recommendation: share the mount and environment logic and keep the argument
   allow-lists separate. A reviewer and an implementer accept different flags, and one
   wrapper with a write switch is easy to get wrong.
3. **Nix daemon for implementers?** codex-implement is already refused. agy-implement can
   reach it today. Recommendation: hide it for both, matching #2748, and leave `nix build`
   to Claude after the step. The alternative is to keep it for agy and accept the risk until
   #2758 settles `trusted-users`.
4. **Codex MCP servers?** Recommendation: start codex-implement with `-c 'mcp_servers={}'`,
   as `agent-review` does. That closes the unknown about headless approval no matter how it
   turns out. If a step needs `nixd`, it can be re-added on its own, inside the sandbox.
5. **agy MCP servers?** They are denied but still start. Recommendation: hide `HOME` from
   them by running agy inside the same sandbox, and leave the adapter's deny-by-default in
   place.
6. **Environment.** Recommendation: `--clearenv` with the same short list as `agent-review`,
   plus whatever each tool's login needs.

## Owner decisions, 2026-11-07

The owner accepted every recommendation above:

1. Sandbox both `codex-implement` and `agy-implement`, rather than only documenting the risk.
2. Share the mount and environment logic with `agent-review`, and keep each tool's argument
   allow-list separate.
3. Hide the Nix daemon socket from both. Claude runs `nix build` after each step. Related: #2758.
4. Start `codex-implement` with `mcp_servers={}`.
5. Run agy, its MCP servers included, inside the sandbox.
6. Clear the environment and pass through an allow-list only.
