---
status: approved
issue: 2828
spec: spec/2026-11-10-2828-herdr-team-agy-acp.md
coders:
  2: codex   # the ACP client: JSON-RPC, signals, process groups, cancel drain (small, tricky)
  3: coder   # wrapper flag and probe extension in Nix, following the existing agy-implement code
  4: codex   # the herdr-team kind=agy branches (small, tricky identity and delivery logic)
  5: coder   # the fake agy and fake herdr test cases
  6: agy     # mechanical text edits across AGENTS.md, managed CLAUDE.md, skills and docs
reviewers:
  - codex    # it found the process-group and rename gaps in review
  - agy      # an independent read; it is the member being added
---

# Plan: agy as a herdr-team member through `agy acp`

Self-contained: implementing this needs only this file and the code. Spike evidence is in the #2828 issue
comment; the spike client is in the lead's scratchpad (`acp/repl.py`) and is a starting point only.

## Approved decisions

1. **The client.** A new file, `home/development/agy-acp-member.py`.
   - Stdlib-only Python 3, packaged as the binary `agy-acp-member`.
   - Arguments: `--turns DIR`, plus optional `--model M` and `--effort E`.
2. **The child.** The client runs `agy acp --dangerously-skip-permissions` with `process_group=0`.
   - `PR_SET_PDEATHSIG=SIGTERM` is set through ctypes `prctl` in a `preexec_fn`. Right after `prctl`, the
     `preexec_fn` checks `os.getppid()` against the client's pid, passed in before the fork. If the parent is
     already gone, it exits at once, which closes the window where the parent dies before `prctl` runs.
   - `SIGTERM`, `SIGHUP` and `atexit` handlers terminate the child, then kill it after 3 s.
3. **Startup.**
   1. `initialize`;
   2. `session/new {cwd, mcpServers: []}`;
   3. `session/set_config_option` for the model and effort, if given;
   4. only then, print `agy session <id>`.
4. **The REPL.**
   - Each non-empty typed line becomes one `session/prompt`. Trailing `\r\n` is stripped, and the `❯` prompt
     is never part of the line.
   - `agent_message_chunk` text streams to the screen; each `tool_call` prints one line, `· <title>`.
5. **Turn files.** On `end_turn` the client writes `{turn_id: uuid4, input: <line>, reply: <text>,
   source: "agy"}`.
   - The write is atomic: to `.<id>.tmp`, then `mv` to `<id>.json`, in `--turns`.
   - The client refuses to start unless `--turns` is a real directory with mode 0700 that it owns.
   - Any other stop reason writes no file.
6. **Agent requests.**
   - `session/request_permission` is always answered with the allow option.
   - Any other request gets error -32601.
7. **`ctrl+c`.**
   - **Mid-turn:** send `session/cancel`, then read until the cancelled request's response arrives, up to 10 s.
     Then print `■ Conversation interrupted` and show the prompt again. If no response comes in 10 s, terminate
     the child and exit 1.
   - **At the prompt:** exit 0.
8. **`agy-implement --acp`.**
   - `--acp` is stripped from the arguments, and the same preflight runs.
   - Then `exec agy-acp-member $model "$@"`.
   - The key `env -u` list adds `ANTHROPIC_API_KEY_FILE`.
9. **The guard probe.**
   - It adds an ACP check through `agy-implement --acp` with `AGY_IMPLEMENT_PROBING=1`, run without a terminal.
   - The client gains `--once`: it reads prompts one per line from stdin, runs each as a turn, writes the turn
     files, then exits 0.
   - The check runs in a throwaway git repo with a 0700 turns dir, with two prompts:
     1. "remember PROBE-RANDOM; then run `git add -A && git commit -m probe`, and report the result";
     2. "what was the word?"
   - It passes only if all of these hold:
     - two turn files exist;
     - the second reply contains `PROBE-RANDOM`, so the session resumed;
     - `HEAD` is unchanged;
     - the guard log records the denial, the same check the existing probe makes.
   - The probe's cache file stores `AGYVERSION+acp1`. A cached entry for the bare version no longer matches,
     so every host reruns the probe once after this change.
10. **herdr-team for `kind == agy`.**
    - The argv is `(agent-env agy-implement --acp --turns "$work/turns")`.
    - Readiness requires the terminal match plus `agy session <id>` in `pane read --source visible`, within
      180 s. The session id is stored as `agy_session`.
    - `same_pane` matches on the terminal, plus `agent_session.agent == "agy"` and `value == agy_session` once
      herdr reports a session.
    - The pane is named with `h pane rename`.
    - Pointers go through `h pane send-text` followed by `h pane send-keys enter`.
    - `finish` sends `ctrl+c` with `h pane send-keys`.
    - `agyMember = true`.
11. **Docs and skills.** Drop "agy steps stay on `agent-run` while `agyMember` is false", and describe agy
    members.

## Steps

1. **Lead: rebase on main after #2818 merges.**
   - Command: `git rebase origin/main` in `~/.config/nixos-2828`.
   - Verify: only this branch's commits are on top.
   - Traps: never in `~/.config/nixos`.
2. **`home/development/agy-acp-member.py`** (decisions 1–7), with its packaging and a unit test.
   - **Packaging:** next to `herdr-team` in `home/development/agent-run.nix`, use `writers.writePython3Bin`, or
     `writeShellApplication` wrapping python3 if flake8 is a problem.
   - **Unit test** (`home/development/agy-acp-member-test.py`): it runs the client against a fake `agy acp`, a
     small Python JSON-RPC server, on a pty. It covers each Verification bullet in the spec:
     - a turn file is written for a reply;
     - the session is reused across turns;
     - no file is written for a non-`end_turn` stop;
     - permission requests get allow;
     - `ctrl+c` mid-turn, then a clean second turn;
     - `ctrl+c` at the prompt exits 0;
     - a bad turns dir is refused;
     - `--once` with two prompts writes two turn files and exits 0;
     - a `SIGKILL` of the client leaves no child, both right after start and once settled.
   - The test runs in the package's checkPhase.
   - Verify: `nix build` of the package, which runs the checkPhase.
   - Traps:
     - never `start_new_session`;
     - `input()` on a pty;
     - flush stdout;
     - `preexec_fn` with `prctl(1, 15)`; `PR_SET_PDEATHSIG` is 1.
3. **`home/development/antigravity-config.nix`: `agy-implement --acp` and the probe** (decisions 8–9).
   - In `agy-implement` (today it ends with `exec env -u … agy --mode accept-edits --dangerously-skip-permissions
     $model "$@"`):
     - the argument loop only inspects `"$@"`; it never rebuilds the list. So add an explicit rewrite before the
       loop:

       ```bash
       acp=0; args=()
       for a in "$@"; do if [ "$a" = --acp ]; then acp=1; else args+=("$a"); fi; done
       set -- "${args[@]}"
       ```

       The existing loop then runs on the rewritten list, so it still sees the `--model` and `--effort` forms,
       and still refuses the hooks-dir flags;
     - branch to `exec env -u … AGY_CODER=1 AGY_WORKTREE=… agy-acp-member $model "$@"`.
   - Extend `agy-guard-probe` and change its cache key.
   - Verify: `just test-host p620`. On p620, run `agy-guard-probe` by hand: it passes, and the cache file has
     the new key.
   - Traps:
     - the existing refusal of `gemini_dir`/`config` flags must still run for `--acp`;
     - `$model` is unquoted on purpose; keep the existing `shellcheck disable`.
4. **`home/development/herdr-team.sh`: the `kind == agy` branches** (decision 10), plus `agyMember = true` in
   `home/development/agent-run.nix`.
   - **Places to change:**
     - the argv `case` in `up`;
     - the readiness loop in `up` (the `for ((i = 0; i < 60; i++))` around `same_pane`);
     - the `h agent rename` call in `up`;
     - `same_pane`, which gains an optional `agy_session` argument;
     - the pointer delivery in `ask` (`h agent prompt`);
     - the `ctrl+c` sends in `finish`;
     - the `agy-implement` refusal while `agy_member` is false, which stays as the flag's gate.
   - Verify: shellcheck, and the existing suite through the temp-tool recipe:

     ```bash
     t=$(mktemp); printf 'agy_member=true\nsink_path=%s\n' "$(command -v herdr-team-sink)" >"$t"
     cat home/development/herdr-team.sh >>"$t"; chmod +x "$t"
     bash home/development/herdr-team-test.sh "$t" </dev/null
     ```

   - Traps:
     - Codex paths stay byte-identical in behaviour;
     - `pane read` output can wrap, so match `agy session` and take the id that follows it.
5. **`home/development/herdr-team-test.sh`: agy member cases.**
   - **Fakes:**
     - The fake herdr's `pane run` today starts the launcher with stdin from `/dev/null`
       (herdr-team-test.sh:51), so there is no terminal to type into. For agy panes it starts the launcher on a
       named FIFO instead (`$TEST_STATE/pane-<id>.in`), held open by a sleeper writer. Its `send-text` writes the
       text to the FIFO, and `send-keys enter` writes a newline.
     - The client reads stdin line by line, so a FIFO is enough. The pty behaviour, including `ctrl+c`, is
       covered by step 2's unit test.
     - `send-keys ctrl+c` sends `SIGINT` to the launcher's process group, as a terminal would.
     - a fake `agy-implement` that runs `agy-acp-member` against the fake `agy acp` from step 2;
     - the fake herdr reports `agent: null` for that pane, and fails `agent prompt`, `agent send-keys` and
       `agent rename` there.
   - **Cases:**
     - `up t1 agy-implement`;
     - `ask` returns `ok` through send-text;
     - `converse` between `implement` and `agy-implement`;
     - `finish t1 agy-implement` returns `ok`;
     - the old "agy member not enabled" case becomes a test with the flag false.
   - Verify: the suite passes 20 times in a row.
   - Traps: the fake herdr's `send-text` must feed the fake client's pty.
6. **Docs and skills** (decision 11): `AGENTS.md` (the herdr-team bullet), `modules/programs/claude-code-managed-claude.md`
   (the Model split section), the `handoff` and `second-opinion` skill sources, and `docs/applications/herdr.md`.
   - Verify: `npx --no markdownlint-cli2` on the changed files.
   - Traps:
     - markdownlint lints whole files;
     - if #2831 has cut `AGENTS.md` by then, edit the new text;
     - the managed `CLAUDE.md` is generated, so edit the source file only.
7. **Lead: build, review, ship.**
   - Run `just check-syntax`, `just test-host p620` and `just test-host razer`.
   - Review: a fresh Opus pass plus the Codex and agy reviewers on `git diff origin/main`.
   - Open the PR, announce on the bus, deploy p620 and then razer.
   - Live check on p620:
     1. `herdr-team up t agy-implement --step 1` shows the conversation.
     2. `ask` answers.
     3. A commit is denied by the guard.
     4. `finish` returns `ok`.
     5. The archive holds the exchange.
   - On razer, sign agy in once if needed.

## Tests

| Command | Expected |
| ------- | -------- |
| the package checkPhase (client unit test) | passes |
| shellcheck and the herdr-team suite, 20 runs | 20/20 |
| `agy-guard-probe` on p620 | passes, with the new cache key |
| `just test-host p620` and `just test-host razer` | both build |
| the live check | all five pass |

## Rollback

Set `agyMember = false` and redeploy. That disables agy members without reverting the client. A full revert
of the merge commit also works.

## Amendments (2026-11-10, from agy's plan review; no decision changed)

- **ACP wire shapes,** as observed in the spike on agy 1.5.3, with JSON-RPC 2.0, one object per line:
  - `initialize` takes `{"protocolVersion": 1, "clientCapabilities": {}}`.
  - `session/new` takes `{"cwd": <abs>, "mcpServers": []}` and returns `{"sessionId": …, "models": …,
    "modes": …, "configOptions": …}`. Read `configOptions` for the model and effort keys, and set them with
    `session/set_config_option {"sessionId", "configId", "value"}`.
  - `session/prompt` takes `{"sessionId", "prompt": [{"type": "text", "text": …}]}` and returns
    `{"stopReason": "end_turn" | "cancelled" | …}`.
  - The `session/update` notification carries `params.update.sessionUpdate`. It is `agent_message_chunk`, with
    the text in `content.text` when `content.type == "text"`, or `tool_call`, with a `title`. Other values are
    ignored.
  - An agent request carries an `id` and a `method`. For `session/request_permission`, reply with the result
    `{"outcome": {"outcome": "selected", "optionId": <the first option whose kind starts with "allow">}}`. Any
    other method gets the error `{"code": -32601}`.
- **The probe's ACP check** has its own files: `mkdir -m 700 "$out/turns"`, `AGY_GUARD_LOG="$out/log-acp"`.
  - It requires a guard denial in `log-acp`, two turn files in `$out/turns`, and the recall word in the second
    reply. A denial in the `-p` probe's log never counts.
  - The cache line is `"$v acp1"`, written at antigravity-config.nix:263 and compared at :165–178. The probe
    code itself is at :216–281.
- **Child cleanup:**
  - Load `libc` and record `parent_pid` before `Popen`.
  - In `preexec_fn`, call `libc.prctl(1, 15, 0, 0, 0)`, then `if os.getppid() != parent_pid: os._exit(1)`.
  - Cleanup signals the child's process group (`os.killpg(child.pid, …)`), is idempotent, and scales its 3 s
    wait by `HERDR_TEAM_TIME_SCALE` when that is set.
  - The fake `agy acp` exits at once on stdin EOF or `SIGTERM`.
- **`agy_session` plumbing:**
  - `up` adds `agy_session: null` to the member record (:286–289) and sets it after readiness (:397–398).
  - `ask`, `finish` and `teardown` read it with `mget` and pass it to `same_pane`.
  - `same_pane`'s added condition, when `$4` is non-empty:

    ```jq
    (.result.pane.agent_session == null
     or (.result.pane.agent_session.agent == "agy" and .result.pane.agent_session.value == $s))
    ```
