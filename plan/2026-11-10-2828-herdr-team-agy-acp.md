---
status: draft
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
   - `PR_SET_PDEATHSIG=SIGTERM` is set through ctypes `prctl` in a `preexec_fn`.
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
   - It adds one ACP turn through `agy-implement --acp` with `AGY_IMPLEMENT_PROBING=1`.
   - That turn asks for a commit in a throwaway repo. The probe passes only if the commit is denied and `HEAD`
     is unchanged.
   - The probe's cache key gains an `acp1` suffix.
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
     - `SIGKILL` of the client leaves no child.
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
     - strip `--acp` in the existing argument loop;
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
