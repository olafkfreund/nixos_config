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
  - It runs `agy acp --dangerously-skip-permissions` as a child in its own process group. There is no
    `start_new_session` (spike trap), so #2818's marker-based stop reaches the child.
  - It sends `initialize`, then `session/new {cwd}`, and prints `agy session <id>`.
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
  - `ctrl+c` during a turn sends `session/cancel`, then prints `■ Conversation interrupted`, the marker `ask`
    already scans for (herdr-team.sh:409), and returns to the prompt.
  - `ctrl+c` at the prompt exits 0.
  - So `finish`'s "one `ctrl+c`, a second after 3 s" gives exit 0, as today.
- **End:** EOF or the child exiting ends the client with the child's code.

### 2. Launch through `agy-implement --acp`

In `home/development/antigravity-config.nix`, `agy-implement` gains `--acp`.

- After the same preflight, it execs `agy-acp-member "$@"` instead of `agy --mode accept-edits … "$@"`. The
  preflight is:
  - the guard probe on a new agy version (#2463);
  - the refusal of flags that would load another `hooks.json` (#2296);
  - `unset CASCADE_GLOBAL_CONFIG_OVERRIDE`;
  - the `env -u` of every key variable;
  - `AGY_CODER=1` and `AGY_WORKTREE`.
- The coder guard is a global `PreToolUse` hook keyed on `AGY_CODER=1`. The spike showed it denies a commit
  under ACP.

### 3. herdr-team changes

These are for `kind == agy` only. Codex paths are untouched.

- **`up`:** `agy-implement`'s argv becomes `(agent-env agy-implement --acp --turns "$work/turns")`.
  `agent-env` keeps the `HERDR_TEAM_MEMBER` marker (#2818).
- **Pane identity:** herdr reports `agent: null` for the client.
  - `same_pane` for agy members matches `terminal_id` only. That is the same terminal identity it checks today;
    the kind check is the part herdr cannot give.
  - The `up` wait loop (herdr-team.sh:384) waits for the client's `agy session` line, through
    `pane read --source visible`, instead of herdr's agent detection.
- **Delivery:** `h agent prompt` returns `agent_not_found`. So agy pointers go through `h pane send-text`
  followed by `h pane send-keys enter`. The pointer line is the same.
- **`finish`:** `h agent send-keys … ctrl+c` becomes `h pane send-keys … ctrl+c` for agy.
- **`agent-run.nix`:** `agyMember = true`.

### 4. Docs and skills

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
  - a permission request is answered allow;
  - `ctrl+c` mid-turn prints the marker, and `ctrl+c` at the prompt exits 0;
  - a turns dir that is not 0700 is refused.
- **herdr-team test:** a fake `agy-implement --acp` running the fake client.
  - `up t1 agy-implement` succeeds.
  - `ask` gets `ok` through send-text delivery.
  - `converse` relays between `implement` (Codex) and `agy-implement`.
  - `finish t1 agy-implement` exits 0 with the usual checks.
  - The existing "agy member not enabled" case is flipped.
- **Live on p620:**
  1. `herdr-team up t agy-implement --step 1` shows the conversation in the pane.
  2. `ask` answers.
  3. A commit attempt is denied by the guard.
  4. `finish` passes.
  5. The archive has the exchange.
- `just test-host p620` and `razer`.
