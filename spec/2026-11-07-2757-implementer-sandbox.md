---
status: draft
issue: 2757
intent: intent/2026-11-07-2757-implementer-sandbox.md
---

# Spec: Sandbox codex-implement and agy-implement

## Design

### What testing found on p620, 2026-11-07

All checks ran in throwaway repos under `/tmp` with `test -r`-style probes only. No model was
involved and no secret value was printed.

| Probe | Result |
| ----- | ------ |
| `codex sandbox -P :workspace -p implement`, `touch .git/probe` and `git add` | **`.git` is read-only.** `git add` fails with `index.lock: Read-only file system` |
| The same, `nix store info` | Daemon `connect` refused, `Operation not permitted`. `nix eval --expr 1+1` works |
| Inside `bwrap --ro-bind / /`, a nested `unshare -Urm` then `mount -o remount,bind,ro /bin` | **EPERM.** bwrap adds `nosuid,nodev` to every bind, and the nested user namespace locks them. This is the same failure as #2298 |
| `unshare -Urm --pid --fork --mount-proc`, tmpfs over `/home` and `/mnt`, then the same nested remount | `~/.ssh` hidden, nested remount **succeeds**, 3 processes visible |

Two consequences shape this design:

- Codex already refuses writes to `.git`, so `codex-implement` cannot stage or commit today.
  The sandbox keeps the git data read-only and loses nothing.
- agy's own `--sandbox` cannot run inside `bwrap`. agy needs a different backend that leaves
  `/bin` alone. The policy can still be shared: which paths, which variables, which checks.

### 1. A shared library, two launchers, two backends

- **`home/development/agent-sandbox.sh`** is a new file. It is a library with no `exec` of its
  own, and it holds what `agent-review.sh` does today outside its argument parsing:
  - The `GIT_*` unset (`agent-review.sh:9-12`).
  - The worktree and home checks (`:18-25`).
  - The read-only host paths: `/nix /etc /usr /bin /lib /lib64 /run/current-system
    /run/systemd/resolve /run/nscd` (`:111-114`).
  - The hidden daemon socket (`:134`).
  - The safe `PATH` filter (`:118-131`).
  - The environment allow-list (`:139-144`).
  - Two exec functions that take one policy:
    - `sandbox_exec_bwrap` is today's `bwrap` call.
    - `sandbox_exec_unshare` is the agy backend in section 4.
- **`agent-review.sh`** keeps its argument allow-list and calls `sandbox_exec_bwrap`. Its
  behaviour does not change, and `agent-review.test.sh` must pass unchanged.
- **`home/development/agent-implement.sh`** is a new file, packaged as `agent-implement`
  next to `agent-review` in `home/development/agent-run.nix:25-29`. It is used as
  `agent-implement <codex|agy> -- <tool arguments>`, and it has its own argument allow-list
  for each tool (section 6).
- Sharing works by concatenation: `text = builtins.readFile ./agent-sandbox.sh +
  builtins.readFile ./agent-review.sh;`, and the same for `agent-implement`. No path is
  sourced at run time. A sourced path is one more thing a caller could redirect.
- **`codex-implement`** (`home/development/codex-cli.nix:27`) does its guard check
  (section 5), then runs `exec agent-implement codex -- -p implement "$@"`.
- **`agy-implement`** (`home/development/antigravity-config.nix:146-197`) keeps every check it
  has today: the guard file, the hooks.json entry, the version probe and the refused flags.
  Its last line changes from `exec agy …` to `exec agent-implement agy -- --mode accept-edits
  --sandbox --dangerously-skip-permissions $model "$@"`. `agent-implement` sets `HOME`,
  `AGY_CODER=1` and `AGY_WORKTREE`. `--dangerously-skip-permissions` is still passed only
  here (#2296).
- **`agent-run`** (`home/development/agent-run.sh:44,49`) is unchanged. It still calls
  `herdr-run … codex-implement` and `herdr-run … agy-implement`, and it still judges the
  result from outside: changed files, `HEAD` and the log.

### 2. What is visible and what is writable

The same for both tools unless noted.

| Path | Inside |
| ---- | ------ |
| `/nix`, `/etc`, `/usr`, `/bin`, `/lib*`, `/run/current-system`, `/run/systemd/resolve`, `/run/nscd` | read-only, as in `agent-review` |
| `/nix/var/nix/daemon-socket` | empty tmpfs, with `NIX_REMOTE=local?read-only=true` |
| `/home`, `/root`, `/mnt`, `/media`, `/srv`, `/opt`, `/snap`, `/var`, `/boot`, `/run` (rest), `/tmp` | empty tmpfs, or absent with bwrap |
| `/proc` | new, in a new PID namespace |
| `/dev` | minimal: `null zero full random urandom tty pts ptmx shm` |
| The task worktree (`git rev-parse --show-toplevel`) | **read-write** |
| The git common dir, which includes `worktrees/<name>/index` and refs | **read-only** |
| `$TMPDIR`, a new `mktemp -d` under `/tmp` that the wrapper removes on exit | read-write |
| Codex: `~/.codex/auth.json` | read-write bind, for token refresh, as in `agent-review` |
| Codex: `~/.codex/implement.config.toml` | read-only bind of the resolved file |
| agy: `~/.gemini` | read-write bind, as today (section 4) |
| `AGY_GUARD_LOG`'s file, only when set | read-write bind of that one file |

Git:

- The common dir is read-only, so the guard is no longer the only thing between the
  implementer and the history. A script the implementer writes and runs cannot commit,
  update a ref or rewrite an object either, and that covers the guard's own admitted gap
  (`modules/programs/claude-coder-guard.sh:9`).
- Staging is not possible. That is already true for Codex, and agy's terminal sandbox
  remounts the workspace and `.git` read-only for commands (#2298 spec, section 2). Claude
  stages and commits after the step, as it does now.
- Read commands still work: `git diff`, `git status`, `git log`. `git status` tries to
  refresh the index and skips quietly when it cannot write it.

Files that must stay writable for a plan step's checks to run:

- The worktree: formatters and `nix-format` write there.
- `$TMPDIR` and `/tmp`: shellcheck, `bash *.test.sh` and `mktemp` write there.
- `$HOME/.cache` inside the tmpfs home: `statix`, `deadnix`, `nix eval` and markdownlint
  write caches there, and they are thrown away.
- Nothing under the common `.git`.

The probe lists exactly these. `just check-syntax`, `statix`, `deadnix`, `shellcheck`,
`nix-instantiate --parse`, `nix eval --expr` and the repo's `*.test.sh` must succeed inside.

### 3. The Nix daemon

The socket directory is an empty tmpfs in both backends, and `NIX_REMOTE` and `NIX_CONFIG`
are set as in `agent-review.sh:143-144`. `nix build`, flake evaluation and `just test-host`
fail inside. The `handoff` skill says so, and Claude runs `just test-host <host>` after each
step that changes Nix (#2758 tracks `trusted-users`).

### 4. agy

- **Backend.** agy runs under `unshare --user --map-current-user --mount --pid --fork
  --mount-proc --kill-child`, followed by a short setup script that uses `mount(8)`:
  - It makes `/` private.
  - It binds what section 2 keeps into a staging tmpfs.
  - It mounts tmpfs over each hidden tree, then moves the staged binds back.
  - It never touches `/bin`, `/usr` or `/nix`, so they keep their host flags, and agy's own
    nested `--sandbox` can remount `/bin` (tested above, row 4).
  - It runs `exec env -i <allow-list> agy …`.
- **`~/.gemini`.** It stays a full read-write bind, as today:
  - #2748 found that agy in a home with only its OAuth token and `config/` has "no usable
    model".
  - A read-only bind is unproven, because agy writes conversation state there.
  - This is no regression: `agy-implement` has full `~/.gemini` access now, and the adapter
    already denies any tool call that names `.gemini` (`agy-guard-adapter.sh:52`).
  - What changes is that nothing else in the home is visible.
- **MCP servers.** Owner decision 5: they run inside the sandbox, so they see what agy sees,
  with no credentials in the environment. In addition, the wrapper binds a store file
  `{"mcpServers":{}}` read-only over agy's MCP config, so none start.
  - Which of `~/.gemini/config/mcp_config.json` and `~/.gemini/antigravity/mcp_config.json`
    agy reads is confirmed in the plan's first agy step.
  - If masking breaks agy's start, drop the mask and keep them inside. The adapter denies
    their calls anyway (`agy-guard-adapter.sh:141`).
- **Login and model.** OAuth refresh writes inside `~/.gemini`, which stays writable. The
  network namespace is shared, because agy must reach its model.
- **The guard.** The hook runs `/etc/antigravity/hooks/coder-guard` (under `/etc`, read-only
  and visible) with `AGY_CODER=1` and `AGY_WORKTREE` from the allow-list. Its writes to
  `AGY_GUARD_LOG` go to the single bound file.
- **A gate, as in #2748.** The plan's first agy step runs a live probe before anything ships:

| Probe result | What happens |
| ------------ | ------------ |
| Login, model, file edits and a sandboxed `git status` work, and secrets are hidden | Ship |
| agy's `--sandbox` fails inside the namespace | Stop and come back. Do not drop `--sandbox` |
| agy's commands have outbound network, or reach `@1PASSWORD_MCP` | Ship, but record it in `AGENTS.md` and `docs/tooling/agy-coder-guard.md`: the hiding still holds, and no secret is in reach to send |
| An MCP server process runs despite the mask | Ship with the mask dropped, record it |

### 5. Codex

- `bwrap` backend, as in `agent-review`. Codex's own `workspace-write` sandbox runs inside
  it, as `read-only` already does, and keeps commands off the network and away from `.git`.
- **MCP:** `-c 'mcp_servers={}'` is always prepended. #2748 saw `rmcp` errors with it, so the
  probe checks that no MCP process runs.
- **Escalation:** `approval_policy = "on-request"` stays. An escalated command now runs inside
  the outer sandbox, so even if a headless escalation is approved, it still cannot see any
  secret.
- **Guard check.** Before `exec`, `codex-implement` refuses to start, exit 1, with a message
  that names #2757, unless both of these hold:
  - `/etc/codex/requirements.toml` has a `[[hooks.PreToolUse.hooks]]` entry whose `command`
    is `/etc/codex/hooks/coder-guard`.
  - That file is executable.
  - The check mirrors `agy-implement`'s at `antigravity-config.nix:150-160`.
- **Hooks that write.** The managed `SubagentStart` and `SubagentStop` hooks
  (`claude-code-managed.nix`, `subagent-inc` and `subagent-dec`) may write outside the
  sandbox. The plan checks where they write. If that place is hidden inside, they fail
  without blocking the run, or the plan binds their one state file.

### 6. Arguments

`agent-implement` refuses the same family `agent-review.sh:64-66` refuses. The exception is
the flags each implementer needs.

| Tool | Allowed | Refused |
| ---- | ------- | ------- |
| codex | `exec`, `-p implement` (added by the launcher), `-o <file>` (bound, see below), `-`, `--ephemeral`, `--json`, `--color`, `-c` with `model`, `model_reasoning_effort` only | `--dangerously-*`, `--yolo`, `--full-auto`, `--add-dir`, `-s`/`--sandbox`, any other `-p`, `--enable`/`--disable`, `--oss`, `-c` with any other key, and any subcommand other than `exec` |
| agy | `--mode accept-edits --sandbox --dangerously-skip-permissions`, which only `agy-implement` adds, plus `--model`, `--effort`, `-p`, `--output-format`, `--print-timeout` | the config-dir and `gemini_dir` family, which `agy-implement` already refuses, `--mode` other than `accept-edits`, and `--add-dir` |

`agent-run` passes `-o "$log.msg"`, with `log` from `mktemp -t` on the host
(`agent-run.sh:41`), so it lies outside the sandbox. Codex writes that file from inside, so
the wrapper creates it and binds that one file read-write, as for `AGY_GUARD_LOG`. Any other
`-o` path is refused.

### 7. Environment

`env -i`, or `--clearenv` with bwrap, followed by:

- **Both:** `PATH` (filtered), `HOME`, `LANG`, `TERM`, `TMPDIR`, `SSL_CERT_FILE`,
  `NIX_REMOTE` and `NIX_CONFIG`, as in `agent-review`.
- **codex:** `CODEX_CODER=1`.
- **agy:** `AGY_CODER=1`, `AGY_WORKTREE=<worktree>` and `AGY_GUARD_LOG` when it is set.

Nothing else passes. Without the `*_CODER` variables both guards allow everything
(`claude-code-managed.nix:331`, `agy-guard-adapter.sh:19`), so the test checks that they are
present inside.

## Alternatives rejected

- **Document the limit only:** the reads are live, and the owner chose to sandbox.
- **bwrap for agy too:** bwrap's forced `nosuid` breaks agy's nested `--sandbox` (tested). That
  would mean dropping `--sandbox`, and then commands could write the worktree directly,
  around the file-tool fence.
- **Drop agy's `--sandbox` and rely on the outer namespace:** this loses the read-only
  workspace for commands and the `BypassSandbox` refusal that relies on it (#2298).
- **One wrapper with a write switch, `agent-review --write`:** an implementer and a reviewer
  accept different flags, and one switch away from a writable review is the mistake to avoid.
- **The unshare backend for `agent-review` too:** `agent-review` works and is tested. Changing
  its backend is outside this issue.
- **A read-only `~/.gemini` with tmpfs over its state directories:** unproven, and #2748 hit
  "no usable model" in a smaller layout. It can follow as a separate step once the gate
  passes.
- **Writable common `.git`, so implementers can stage:** that would put the history behind a
  guard that only matches command text. Claude stages after the step.
- **Keep the daemon for agy:** decided against by the owner (decision 3).
- **A separate user or a VM per run:** stronger, but heavier than this needs, as #2748 found.

## Risks

- **Handoffs break.** Anything a plan step's checks write outside section 2's list fails,
  most likely a tool cache outside `$HOME/.cache`, or `nix build`. Steps that need a build fail
  where they used to pass. The `handoff` skill must say that Claude builds, and `agent-run`'s
  verdict stays on changed files, so a failed check shows in the log, not as a silent pass.
- **agy-guard-probe** (`antigravity-config.nix:203`) runs on the first `agy-implement` of a new
  agy version:
  - Its repo is a `mktemp -d` under `/tmp`, which is a tmpfs inside. The worktree bind
    must come after the tmpfs. The test covers a worktree under `/tmp`.
  - Its `AGY_GUARD_LOG` is outside that repo, so the log file is bound. If the bind is
    missing, the probe fails closed and agy-implement refuses. That is safe, but it stops
    every handoff.
  - Its `$out/x` and `.gemini/probe` checks still test the guard, because the guard denies
    them whatever the mounts allow.
- **Login refresh.** Codex refreshes through the bound `auth.json`, which already works in
  `agent-review`. agy refreshes in `~/.gemini`, which stays writable. An expired token is
  tested on purpose in the probe.
- **razer.** Untested. Hybrid Optimus does not matter here, but envfs and the `/bin` suid
  remount service (`claude-code-managed.nix:1076-1085`) must be present there, and user
  namespaces must be allowed. The probe is repeated on razer before the issue closes.
- **p510.** Not a target, and implementers are not run there.
- **Nested namespaces.** Codex's linux-sandbox inside `bwrap` with `workspace-write` has not
  been run yet, only `read-only` (#2748). The test and the probe cover it.
- **herdr-run** (`home/development/herdr-run.sh:118-125`) writes the caller's whole
  environment to a file for its pane. That file is outside the sandbox and not changed
  here. The plan records whether it should be its own issue.
- **Visible by design:** each tool's own login, `~/.gemini` for agy, the repo, which includes
  encrypted `.age` files, and whatever is world-readable under `/nix`, `/etc` and `/usr`.
  `AGENTS.md` and `docs/tooling/agy-coder-guard.md` say so.

## Verification

1. `bash modules/programs/agy-guard-adapter.test.sh </dev/null` passes unchanged.
2. `bash home/development/agent-review.test.sh </dev/null` passes unchanged after the
   refactor.
3. New `home/development/agent-implement.test.sh`, in the shape of `agent-review.test.sh`:
   - It plants a fake `codex` and a fake `agy` that record their argument list, the names
     of their environment variables and a probe.
   - The probe checks: the hidden paths are absent; the worktree and `$TMPDIR` are
     writable; the common dir is read-only; only the tool's own login is visible; the
     daemon socket is absent; the `*_CODER` and `AGY_WORKTREE` variables are present; no
     other caller variable is present.
   - A worktree under `/tmp` works, as agy-guard-probe uses one.
   - A refused argument from each column of section 6 exits non-zero and does not run the
     tool.
   - A failing backend (fake `bwrap` or `unshare`) exits non-zero and does not run the
     tool.
   - `codex-implement`'s guard check refuses when `requirements.toml` lacks the hook.
   - Prints SKIP, not a pass, without user namespaces.
   - **Mutation checks**, via `AGENT_IMPLEMENT=<path>` as `agent-review.test.sh:5` does:
     each of these copies must turn a check red:
     - with the `--clearenv`/`env -i` removed;
     - with the common dir bound read-write;
     - with the daemon tmpfs removed;
     - with `AGY_CODER` dropped from the allow-list;
     - with the agy backend switched to `bwrap`, where the nested remount must fail.
4. `just check-syntax`, and `just test-host p620` and `just test-host razer` (built on p620).
5. **Live probe after the p620 deploy.** Announce on the bus first, and use `test -r` only.
   Run it for both implementers against #2748 plan step 8's list:
   - Hidden: an agenix secret, `~/.ssh/id_ed25519`, `~/.config/gh/hosts.yml`, the other
     tool's login, the session bus, `/mnt`, `/var/lib`, other users' homes, Nix
     `access-tokens` and another process's `/proc/<pid>/environ`.
   - Environment: names only; none holds a credential.
   - The daemon socket is hidden; `nix build` and flake evaluation fail; `nix eval --expr`,
     `nix-instantiate --parse`, `statix` and `git log` work.
   - Forbidden: `git commit`, `git push`, `git update-ref` and `ssh p510` fail.
   - Network and `@1PASSWORD_MCP` from a command: blocked for Codex. For agy, whatever the
     result, it is recorded per section 4.
   - No MCP server process runs for either tool.
   - Writable: one file edit in the worktree lands. Nothing lands in the common `.git`.
   - Working: login, including a forced refresh, and a real `agent-run codex` and
     `agent-run agy` on a one-line throwaway plan step, which return `ok: true`.
   - The agy-guard-probe passes from a cleared `probed` cache.
6. The same probe on razer after `just deploy-via-p620 razer`.
