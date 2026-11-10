---
status: draft
issue: 2828
intent: intent/2026-11-10-2828-herdr-team-agy-acp.md
---

# Spec: agy as a herdr-team member through `agy acp`

The spike results are in the issue comment (2026-11-10):

- items 1–4 pass: reply plus `end_turn`, resume, no permission stops, and the coder guard fires under ACP;
- item 5 is partial: herdr does not detect the client as an agent, but text delivery, the session report and a
  clean `ctrl+c` work.

## Design

### 1. `agy-acp-member`, a pane-mode ACP client

A new file, `home/development/agy-acp-member.py`. It is stdlib-only Python and is packaged with
`writers.writePython3Bin` (or `writeScriptBin` with python3), so it gets flake8 checks at build time.

- **Start:**
  - It runs `agy acp --dangerously-skip-permissions` as a child in its **own process group**
    (`process_group=0`). So a terminal `ctrl+c` reaches only the client, and the child survives to handle
    `session/cancel`.
  - It still inherits `HERDR_TEAM_MEMBER`, and the client guarantees the child dies with it:
    - `PR_SET_PDEATHSIG = SIGTERM` is set in the child through `prctl` (ctypes) before `exec`. So even a
      `SIGKILL` of the client from #2818's `stop_member` or the watchdog takes the child down.
    - On top of that, `SIGTERM`/`SIGHUP` handlers and `atexit` terminate the child, then kill it after 3 s.
  - This replaces the spike's `start_new_session`. A separate session would also drop the controlling
    terminal, which the child does not need.
  - It sends `initialize`, then `session/new {cwd}`, then the model and effort config, and only then prints
    `agy session <id>`. So `up` cannot see the member as ready before it is configured.
  - Its argv takes `--turns <dir>` (the member's `<work>/turns`) and an optional `--model`/`--effort`, which it
    applies with `session/set_config_option`, as the prior art does.
- **REPL:**
  - It reads lines from the terminal; each non-empty line is one `session/prompt`.
  - It echoes the line, streams `agent_message_chunk` text, and prints one `· <title>` line per `tool_call`.
    The owner watches the conversation (intent constraint).
- **Turn files:**
  - At `stopReason: "end_turn"` it writes `{turn_id: <uuid4>, input: <the typed line>, reply: <full text>,
    source: "agy"}` to `<turns>/.<id>.tmp`, then `mv`s it to `<id>.json`. That is the shape and atomic write of
    `herdr-team-sink`, which `ask` already accepts with `source == "agy"` (herdr-team.sh:517).
  - It refuses to start unless `<turns>` is a real 0700 directory it owns, the same rule as the sink.
  - Any other `stopReason` is printed, and no turn file is written, so `ask` times out or sees the interrupt
    marker, as with Codex.
- **Permissions:**
  - Every `session/request_permission` is answered with the allow option, unconditionally, as #2812 requires
    (with `--dangerously-skip-permissions` there were none in the spike).
  - Any other client request gets JSON-RPC error -32601.
- **Interrupt:**
  - `ctrl+c` during a turn sends `session/cancel`, then keeps reading until the cancelled request's response
    arrives (`stopReason: "cancelled"`), up to 10 s, so stale chunks never leak into the next turn. Then it
    prints `■ Conversation interrupted`, the marker `ask` already scans for (herdr-team.sh:409), and returns to
    the prompt. If no response comes within 10 s, it terminates the child and exits 1.
  - `ctrl+c` at the prompt exits 0.
  - So `finish`'s "one `ctrl+c`, a second after 3 s" gives exit 0, as today.
- **End:** EOF or the child exiting ends the client with the child's code.

### 2. Launch through `agy-implement --acp`

In `home/development/antigravity-config.nix`, `agy-implement` gains `--acp`.

- `--acp` is removed from the arguments. After the same preflight, the wrapper execs
  `agy-acp-member $model "$@"` instead of `agy --mode accept-edits … $model "$@"`. `$model` is the default
  `--model gemini-4-argon-medium`, unless the caller set `--model`/`--effort` (antigravity-config.nix:184).
  The preflight is:
  - the guard probe on a new agy version (#2463);
  - the refusal of flags that would load another `hooks.json` (#2296);
  - `unset CASCADE_GLOBAL_CONFIG_OVERRIDE`;
  - the `env -u` of every key variable, including `ANTHROPIC_API_KEY_FILE` (#2818);
  - `AGY_CODER=1` and `AGY_WORKTREE`.
- The coder guard is a global `PreToolUse` hook keyed on `AGY_CODER=1`. The spike showed it denies a commit
  under ACP.

### 3. herdr-team changes

These are for `kind == agy` only. Codex paths are untouched.

- **`up`:** `agy-implement`'s argv becomes `(agent-env agy-implement --acp --turns "$work/turns")`.
  `agent-env` keeps the `HERDR_TEAM_MEMBER` marker (#2818).
- **Readiness:** herdr reports `agent: null` for the client.
  - For agy, `up`'s wait loop (herdr-team.sh:384) requires both the terminal match and the client's
    `agy session <id>` line in `pane read --source visible`.
  - It records `<id>` in the member's state as `agy_session`.
  - The loop waits up to 180 s instead of 60 s, because `agy-implement`'s first run on a new agy version runs
    the guard probe first (about 90 s, plus the ACP check below).
- **Pane identity:** `same_pane` for agy matches `terminal_id`, as today. Once herdr reports `agent_session`
  (after the first turn), it also requires `agent_session.agent == "agy"` and `value == agy_session`.
  `kind` is not checked for agy, because herdr cannot report it.
- **Naming:** `h agent rename` needs a detected agent. agy members are named with `h pane rename` instead
  (herdr-team.sh:394).
- **Delivery:** `h agent prompt` returns `agent_not_found`. So agy pointers go through `h pane send-text`
  followed by `h pane send-keys enter`. The pointer line is the same.
- **`finish`:** `h agent send-keys … ctrl+c` becomes `h pane send-keys … ctrl+c` for agy.
- **`agent-run.nix`:** `agyMember = true`.

### 4. The guard probe gains an ACP check

`agy-guard-probe` (antigravity-config.nix:162–199) adds one ACP turn through the guarded path: `agy-implement
--acp` with `AGY_IMPLEMENT_PROBING=1`, so the probe does not recurse. It runs against a throwaway repo, asks
for a commit, and passes only if the commit is denied and `HEAD` is unchanged.

The probe's success cache key gains an `acp1` suffix, so hosts that already cached the current agy version
run the new check once.

### 5. Docs and skills

- `docs/applications/herdr.md`: agy members, and how they differ (no herdr agent detection, typed delivery).
- `AGENTS.md`'s herdr bullet, the managed `CLAUDE.md` text in `modules/programs/claude-code-managed.nix`, and the
  `handoff`/`second-opinion` skills: drop "agy steps stay on `agent-run` while `agyMember` is false".

## Alternatives rejected

- **The agy TUI in the pane plus a hook-based answer:** the `Stop` hook carries no reply text, which is the
  original blocker.
- **Screen-scraping agy's TUI for the reply:** herdr-team deliberately counts only the agent's own turn record,
  never a screen read.
- **A headless ACP member with no pane:** the owner asked to watch the agents.
- **Bash plus `jq` with a coprocess for JSON-RPC:** fragile with streaming and interleaved requests. Python is
  already on every host, and the stdlib is enough.
- **Teaching herdr to detect the client:** herdr's detection is upstream code. Matching by terminal is enough
  for herdr-team.
- **Running `agy acp` without `agy-implement`:** that would skip the guard preflight and the flag refusals.

## Risks

- **ACP is new in agy (1.5.x).** Message names may change on an update.
  - Mitigation: the client fails closed. With no `end_turn`, there is no turn file and `ask` times out.
  - `agy-implement`'s new-version probe runs anyway.
  - A short live ACP check (the spike's two-turn recall) is added to that probe.
- **Terminal-only pane identity:** a pane replaced by another program in the same terminal would still match.
  The marker-based stop (#2818) and the `ctl` pid and start checks still guard signalling. A wrong pane could
  receive one pointer line, as with any typed delivery.
- **Typed delivery while the client is mid-turn:** a line typed during a turn is read after it. `ask` already
  refuses a second pending request.
- **Hosts:** p620 and razer through Home Manager. Razer's agy login is per host. Its first use needs agy
  signed in there.

## Verification

- **Client unit test** (packaged check), against a fake `agy acp` written in Python that speaks the spike's
  messages:
  - one turn writes a well-formed turn file with `source: "agy"`;
  - a second turn reuses the session;
  - a non-`end_turn` stop writes no file;
  - a `ctrl+c` mid-turn followed by a new prompt: the second turn gets its own reply, with no stale chunks from
    the cancelled one;
  - a `SIGKILL` of the client leaves no `agy acp` process (`PDEATHSIG`);
  - a permission request is answered allow;
  - `ctrl+c` mid-turn prints the marker, and `ctrl+c` at the prompt exits 0;
  - a turns dir that is not 0700 is refused.
- **herdr-team test:** a fake `agy-implement --acp` running the fake client.
  - The fake herdr reports `agent: null` for that pane, and fails `herdr agent prompt`, `send-keys` and
    `rename` on it, so any leftover `h agent` call is caught.
  - `up t1 agy-implement` succeeds.
  - `ask` gets `ok` through send-text delivery.
  - `converse` relays between `implement` (Codex) and `agy-implement`.
  - `finish t1 agy-implement` exits 0 with the usual checks.
  - The existing "agy member not enabled" case is flipped.
- **Probe:** the ACP probe passes on p620 and is recorded under the new cache key.
- **Live on p620:**
  1. `herdr-team up t agy-implement --step 1` shows the conversation in the pane.
  2. `ask` answers.
  3. A commit attempt is denied by the guard.
  4. `finish` passes.
  5. The archive has the exchange.
- `just test-host p620` and `razer`.
