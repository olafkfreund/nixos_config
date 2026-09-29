---
status: approved
issue: 2087
intent: intent/2026-09-29-2087-agy-coder-write-access.md
---

# Spec: Antigravity may write code for approved plans

## What the probes established

Every design decision below rests on live probes of `agy` 1.2.12 on p620,
2026-09-29. Each probe was run in a throwaway repo, and each probe hook was
removed afterwards.

| Question | Evidence |
|---|---|
| Where are hooks read? | `~/.gemini/config/hooks.json` fires. Workspace `.agents/hooks.json` is ignored ([google-antigravity/antigravity-cli#1036](https://github.com/google-antigravity/antigravity-cli/issues/1036), open). |
| Is a trust step needed? | **No.** A new global hook fired at once, with no prompt. This is unlike Codex (#2085). |
| What does the hook receive? | `toolCall.name` = `run_command`, and the command at `toolCall.args.CommandLine`, plus `Cwd`, `modelName`, `conversationId` and `workspacePaths`. There is **no** `tool_input.command`, so the shared guard used unchanged would fail open. |
| How does a hook deny? | `{"decision":"deny","reason":…}` on stdout gives "tool call denied by pre-tool hook: \<reason\>". Exit 2 also blocks, reported as a failed hook. |
| Does the hook inherit env from `agy`? | **Yes.** With `AGY_CODER=1 agy …`, the hook saw `AGY_CODER=1`. |
| Where does the hook run? | In `~/.gemini/config`, so the command path must be absolute. |
| What happens when a hook fails? | The tool call is blocked. A missing or broken hook command therefore blocks every `agy` terminal call in every session. |

**A blocker found on the way.** The plugin `googlecloudtools.datacloud_telemetry`
(`~/.gemini/config/plugins/`, installed 2026-07-20 from the Antigravity
IDE) replies `{"continue":true}`. `agy` 1.2.12 rejects that reply ("unknown
field continue"), so **every `agy` terminal command currently fails.** That
includes yours, and it would include `agy-implement`.

## Design

### 1. The guard: an adapter in front of the shared script

A new file, `modules/programs/agy-guard-adapter.sh`, sits next to
`claude-coder-guard.sh`. It is installed by `claude-code-managed.nix` at
`/etc/antigravity/hooks/coder-guard` on every host, the same way Codex's
guard sits in `/etc/codex/hooks/`. It:

1. prints `{"decision":"allow"}` and exits, unless `AGY_CODER=1`, so plain
   `agy` is never touched;
2. reads `toolCall.args.CommandLine` from the payload with `jq`, and allows
   when there is no command, so file edits and reads pass;
3. passes `{"tool_input":{"command": …}}` to the shared guard. On exit 2
   it prints `{"decision":"deny","reason":"<the guard's message>"}`, and
   otherwise `{"decision":"allow"}`.

The shared guard is not changed. Its 88-case test covers the matching, and
the adapter only translates the payload in and the result out.

### 2. Registration, on a synced path

The only hook location that works, `~/.gemini/config/hooks.json`, is inside
the Syncthing allowlist (`!config/**`). A new activation entry,
`antigravityCoderGuardHook` in `home/development/antigravity-config.nix`,
merges this entry in as a real file, add-only:

```json
{ "coder-guard": { "PreToolUse": [ { "matcher": "*", "hooks": [
  { "type": "command", "command": "/etc/antigravity/hooks/coder-guard", "timeout": 10 } ] } ] } }
```

It follows the style of the existing `antigravityMcpSync`: `jq` merge, keep
what's there, leave the file alone if it isn't valid JSON. The command path
is absolute, outside the store and the same on every host, so Syncthing
copying the file between p620 and razer is harmless.

**p510 needs one check.** If `~/.gemini` also syncs to p510, the file
exists there too, because `claude-code-managed.nix` runs on all three hosts.
Verification step 2 checks that before deploy.

### 3. `agy-implement`: the only write entry point, failing closed

A `writeShellScriptBin` in `antigravity-config.nix`. **Before** starting
`agy` it checks two things:

- `/etc/antigravity/hooks/coder-guard` exists and is executable;
- `~/.gemini/config/hooks.json` has the `coder-guard` entry.

If either check fails, it prints why and exits 1. It never runs unguarded.
Otherwise it runs:

```bash
AGY_CODER=1 exec agy --mode accept-edits --model gemini-3.8-flash-medium --sandbox "$@"
```

- **`--sandbox`** (terminal restrictions) is defence in depth, in the same
  way as `codex-implement`'s `workspace-write`. If the live probe shows
  `--sandbox` stops `just check-syntax` from running, it is dropped and
  recorded in `plan/`. The guard, not the sandbox, is the enforcement.
- **The prompt goes last.** `agy` insists on it: with `-p` followed by other
  flags, `-p` takes the next flag as its prompt. The wrapper puts `"$@"`
  after every flag, so `agy-implement -p "…"` works.

### 4. Model by stage

Session models are chosen per call with `--model`. `agy` has no
`review_model` setting.

| Stage | Model | How |
|---|---|---|
| Intent, spec, plan, revision decisions | `gemini-3.1-pro-high` | `agy --model gemini-3.1-pro-high` |
| Implementation of an approved `plan/` | `gemini-3.8-flash-medium` | `agy-implement` |
| Review of the diff | `gemini-3.1-pro-high` | `agy --mode plan --model gemini-3.1-pro-high` |

This keeps `agy` on Google's own models. Claude Opus and Sonnet are already
covered directly by #2079.

### 5. The rules

- **`AGENTS.md` ("Delegating to other models").** The existing
  `codex-implement` bullet gains `agy-implement` as its twin. The ban on
  `agy --mode accept-edits` becomes "for delegated use", the same wording
  as Codex.
- **`second-opinion/SKILL.md`.** agy stays in `--mode plan` for second
  opinions. Implementing is `agy-implement`'s job.
- **A new `home/development/agent-rules/agy-standards.md`.** It is passed
  into the `.gemini/AGENTS.md` build in `agent-rules.nix`, the way
  `codex-standards.md` is for Codex. Its "Model by stage" section follows
  the table above and says to name the next stage's model and command at
  every gate.

### 6. The telemetry plugin (prerequisite, your decision)

`agy-implement` cannot run a single command while
`googlecloudtools.datacloud_telemetry` is enabled. Neither can plain `agy`.

The recommendation is to **disable it** (`agy plugin disable
googlecloudtools.datacloud_telemetry`), as a one-time command on p620 and
razer, not in Nix. Its only job is to send telemetry to Google Cloud, and in
its current form it breaks the CLI. Approving this spec approves that
command. If you want to keep the telemetry instead, the only way is a patch
to the plugin's reply (`{"continue":true}` becomes
`{"decision":"allow"}`), which the next plugin update overwrites. The spec
does not take that route.

### Decisions on the intent's open questions

| # | Question | Decision |
|---|----------|----------|
| 1 | Models | Gemini 3.1 Pro (High) plans and reviews; Gemini 3.8 Flash (Medium) implements. |
| 2 | Hook trust | Not needed: probed. The guard is a global user hook; workspace hooks are broken upstream. |
| 3 | Sandbox | `--sandbox` is on, unless the probe shows it stops checks from running. The guard is the enforcement. |
| 4 | Commits | agy does not commit. The guard blocks `git commit`, as for Claude's coder and Codex. |

## Alternatives rejected

- **Workspace `.agents/hooks.json`.** It would not sync, but agy ignores it
  (#1036).
- **Using the shared guard unchanged.** agy's payload has no
  `tool_input.command`, so the guard would allow everything: the same
  fail-open as the first Codex deploy.
- **`/etc/antigravity/admin_settings.json`.** The binary reads it, but
  nothing documents hooks in it. A global user hook needs no trust anyway.
- **A Nix store path as the hook command.** Syncthing would copy one host's
  store path to the other, where it doesn't exist. The failed hook would
  then block every `agy` call on that host.
- **Keeping the telemetry plugin and working around it in the guard.** The
  plugin fails on its own, after our hook has run. No hook of ours can fix
  another hook's reply.

## Risks

- **The guard's file must exist wherever `hooks.json` syncs to.** If it is
  missing, the hook fails and every `agy` call on that host is blocked. That
  fails closed, but it breaks plain `agy` too. It is covered by installing
  the file on every host that has `claude-code-managed.nix`, and by the
  check of p510's Syncthing in verification step 2.
- **Other shell-like tools.** Only `run_command` was seen. The adapter
  checks `args.CommandLine` whatever the tool name, so a second terminal
  tool that uses the same field is covered. One that uses a different field
  is not, and the probe only proves `run_command`.
- **`--sandbox` is undocumented.** The probe decides whether it stays.
- **Hosts.** p620 and razer. p510 only if you ask.

## Verification

1. **Build.** `just check-syntax`; `just test-host p620` and `just test-host razer`; the shared guard test.
   An adapter test, `modules/programs/agy-guard-adapter.test.sh`, feeds
   recorded agy payloads to the adapter and checks the output:
   - `git commit` with `AGY_CODER=1` gives a deny;
   - `git status` with `AGY_CODER=1` gives an allow;
   - `git commit` without `AGY_CODER` gives an allow;
   - a tool call with no `CommandLine` gives an allow.
2. **Before deploy: does `~/.gemini` sync to p510?** Check with the
   Syncthing REST API or its config. If it does, confirm p510 gets
   `/etc/antigravity/hooks/coder-guard` from `claude-code-managed.nix`.
3. **After deploy (p620), with the telemetry plugin disabled:**
   - `ls -l /etc/antigravity/hooks/coder-guard` shows the file;
   - `~/.gemini/config/hooks.json` has exactly one `coder-guard` entry;
   - `~/.gemini/AGENTS.md` has "Model by stage".
4. **Live probe in a throwaway repo:**
   - `agy-implement` asked to run `git commit --allow-empty -m probe` and
     `git status`. The commit is refused with "tool call denied by pre-tool
     hook: BLOCKED by the coder guard", `git status` runs, and the repo
     keeps one commit.
   - Plain `agy --mode accept-edits` in the same repo gets no guard
     message.
   - The payload log shows `modelName` = `gemini-3.8-flash-medium`.
5. **Fail-closed check.** With the `coder-guard` entry temporarily
   removed from `hooks.json`, `agy-implement` refuses to start.
