---
status: approved
issue: 2657
spec: spec/2026-11-03-2657-herdr-headless-agent-rows.md
coders:
  1: codex   # herdr-run.sh and its self-test together: small, tricky logic (claim race, traps, process groups), and the fake must match the real calls
  2: coder   # Nix packaging plus the agent-run.sh prefixes, one coupled change
  3: agy     # mechanical prefix edits across two SKILL.md files
  5: coder   # a docs section
reviewers:
  - codex    # it shaped the design; checks the diff against its findings
  - agy      # its plan review drove this revision
---

# Plan: Codex and agy runs show in the herdr sidebar under their Claude lead

Everything needed to implement is here. The spec and intent are background.

## Approved decisions (from the spec)

- **The tool:** `herdr-run <label> <command> [args...]`, with `<label>`
  `codex` or `agy`. The first thing it does is take the label and `shift`.
  To the caller it is transparent: same stdin, stdout, stderr and exit code.
  Callers only add the prefix.
- **Outside herdr** (`HERDR_ENV` is not `1`, or `HERDR_SOCKET_PATH`,
  `HERDR_TAB_ID` or `HERDR_WORKSPACE_ID` is unset): `exec "$@"` after the
  shift, and nothing else.
- **Inside herdr,** in order:
  1. **Private directory:** `mktemp -d`, mode 0700. It holds:
     - `stdin`: always created. It holds the caller's stdin read in full,
       or is empty when stdin is a terminal (`[ -t 0 ]`).
     - `env`: `export -p` with readonly variables and `BASH*`/`SHELLOPTS`
       filtered out, plus the cwd.
     - `run`: the runner, with the arguments quoted by `printf '%q'`.
  2. **Tab:** under `flock` on `$XDG_RUNTIME_DIR/herdr-run-<lead tab>.lock`:
     - `tab create`.
     - Record `.result.root_pane.pane_id`, `.result.tab.tab_id` and
       `.result.root_pane.terminal_id`.
     - **Send `split_mark` at once, while still holding the lock,** so a
       parallel run sees this tab as a child.
     - Place the tab with socket `tab.move`, as
       `if ! socat …; then :; fi`. A failed or refused move is ignored and
       the run carries on in the created pane, wherever it sits. Release
       the lock.
  3. **Handshake:** send `pane run`, then wait up to 3 s for `claim`, up
     to 3 sends.
     - A late copy finds `claim` taken and exits.
     - If no copy has claimed, the helper tries `mkdir claim` itself. If
       that succeeds, it closes its pane (identity-checked) and runs the
       command headless with `< stdin`. If it fails, a runner won at the
       last moment, and the helper carries on waiting.
  4. **Runner:** no `set -e`, see step 1.
  5. **Helper:**
     - Sends `report-agent working`.
     - Re-sends `split_mark` at about 2, 6 and 15 s, from a background job
       that is killed on exit.
     - Waits for `status`. Every 5 s it checks that the pane exists and
       `runner.pid` is alive. If either is gone, it KILLs the group,
       replays the partial output, prints `herdr-run: <label> run lost
       (pane closed or runner died); not re-run` to stderr and exits 1.
  6. **End:**
     - Replay `out` to stdout and `err` to stderr.
     - Report `idle`, wait 3 s, then `release-agent` and `pane close`.
     - Remove the directory and exit with the code from `status`.
- **Identity:** before every report, release and close, `pane get` must
  still show the recorded `terminal_id`.
- **Ctrl-C or SIGTERM to the helper:** TERM to the command's group, KILL
  5 s later, close the pane, exit 130 or 143.
- **Any herdr failure before a claim:** as the end of point 3, a headless
  run with `< stdin`.
- **Callers:**
  - `second-opinion`: the `codex review`, `codex exec`, `agy` and
    `agy --agent` blocks.
  - `agent-run.sh`: lines 44 and 49, with the retry loop outside the
    wrapper.
  - `handoff`: the direct `agy-implement --model` example.
- `herdr.nix` is unchanged.

### Deviations from the spec (found while planning)

1. **Recognising child tabs.** The spec places a tab "after any
   consecutive tabs whose label starts with `↳`". That cannot work: the
   auto-title plugin rewrites labels (a live `tab.list` on 2026-11-03 showed
   `2 · agy`). A tab counts as a child when its root pane carries a
   `split_mark` token, which is what the sidebar draws. That covers
   herdr-run tabs and herdr-claude-teams teammates alike. herdr-run sends
   its own `split_mark` at creation, under the lock, so parallel runs see
   each other.
2. **herdr is not a runtime input.** The tool calls `"${HERDR_BIN_PATH:-herdr}"`.
   herdr sets `HERDR_BIN_PATH` in every pane, to the running server's
   binary, so p510 does not gain herdr in its closure. `procps` is added
   for `pgrep`.
3. **No `tee`.** The command writes straight to `out` and `err`, and the
   pane shows them with `tail --pid`. That removes a race where a
   process-substitution `tee` could still be flushing after `status`
   appeared.
4. **Title rule:** `<label> implement` when an argument is exactly
   `codex-implement` or `agy-implement`, else `<label> review`. The
   spec's "first word" would be `timeout`. A substring match would also
   hit prompt text.

## Interfaces the code must use (verified live on p620, 2026-11-03)

| Call | Form | Reply fields used |
|---|---|---|
| create | `herdr tab create --workspace W --cwd D --label "↳ L" --no-focus` | `.result.root_pane.pane_id`, `.result.root_pane.terminal_id`, `.result.tab.tab_id` |
| get | `herdr pane get P` | `.result.pane.terminal_id`, `.result.pane.tokens.split_mark` |
| run | `herdr pane run P "<line>"` | exit code only |
| state | `herdr pane report-agent P --source herdr-run --agent L --state working\|idle` | — |
| mark | `herdr pane report-metadata P --source herdr-run --token "split_mark=↳ L"` | — |
| release | `herdr pane release-agent P --source herdr-run --agent L` | — |
| close | `herdr pane close P` | — |
| socket | one line `{"id":"1","method":M,"params":{…}}` to `socat -t5 - UNIX-CONNECT:"$HERDR_SOCKET_PATH"` | — |
| `tab.list` | params `{"workspace_id":W}` | `.result.tabs[].tab_id` |
| `pane.list` | params `{"workspace_id":W}` | `.result.panes[] \| {pane_id, tab_id}` |
| `tab.move` | params `{"tab_id":T,"insert_index":N}` (0-based, counted before removal) | — |

## Steps

1. **`home/development/herdr-run.sh` and `home/development/herdr-run-test.sh`**
   (new, one coder). The helper is as decided above.
   - **The runner** is written into the private directory as a here-doc,
     with the quoted command and the paths baked in. It does not use
     `set -e`.
     1. `mkdir claim || exit 0`.
     2. Write `runner.pid` (via `.tmp` then `mv`).
     3. Set an `EXIT` trap. It writes `status` as `127` (via `.tmp` then
        `mv`) only if `status` does not exist yet, and it kills the
        watchdog.
     4. Start the watchdog in the background. Every 2 s it checks the
        helper PID. If the helper is gone, it sends TERM to the group,
        KILL 5 s later, and then runs `pane close` on itself, after the
        identity check.
     5. Print OSC 0.
     6. `: > out; : > err`, so `tail` can open both files.
     7. Start the command **in the background**, keeping its PID:

        ```bash
        setsid -w env -i bash --noprofile --norc -c \
          'source env && cd "$cwd" && [ ! -e cancel ] &&
           echo $$ > cmd.pgid.tmp && mv cmd.pgid.tmp cmd.pgid &&
           exec "$@"; exit 127' _ "${cmd[@]}" < stdin > out 2> err &
        cpid=$!
        ```

        Each setup step must succeed before `exec`. A failed `source` or
        `cd`, or a `cancel` file, ends in 127 without running the command.
     8. Run `tail --pid="$cpid" -f out err &` for the live view, then
        `wait "$cpid"; code=$?`.
     9. Write `$code` to `status.tmp`, then `mv` it to `status`.
   - **Process groups:** every `kill` of the command's group reads
     `cmd.pgid`, requires `[[ $pgid =~ ^[0-9]+$ ]] && (( pgid > 1 ))`, and
     sends `kill -TERM -- "-$pgid"`.
   - **Cancelling before `cmd.pgid` exists** (a signal right after the
     claim):
     - The helper's trap first writes `cancel`, which the inner `bash`
       checks just before `exec`.
     - It then waits up to 2 s (scaled) for either `cmd.pgid` or `status`
       to appear.
     - If `cmd.pgid` appears, it kills that group. If neither appears,
       `cancel` keeps the command from starting.
     - Only then does it close the pane.
   - **Insert position:**
     - Take `tab.list` and `pane.list`, and find the index of
       `HERDR_TAB_ID`.
     - Walk the following tabs. For each, `pane get` its first pane from
       `pane.list` and keep walking while `.tokens.split_mark` is set.
       Insert at the first tab without it.
   - **Timing:** every wait in `herdr-run.sh` is multiplied by
     `HERDR_RUN_TIME_SCALE`, default `1`. The self-test sets it to
     `0.05`. It is the only test hook in the tool, and it is documented in
     the tool's usage text.
   - **The self-test** takes the built tool's path as `$1`. It creates
     `XDG_RUNTIME_DIR` and a temp directory, and puts a fake `herdr`
     there. Point at it with `HERDR_BIN_PATH`, never via `PATH`, because
     `writeShellApplication` prepends its own `runtimeInputs` to `PATH`.
     It sets `HERDR_ENV=1`, fake `HERDR_TAB_ID` and `HERDR_WORKSPACE_ID`,
     and a `HERDR_SOCKET_PATH` served by a real `socat
     UNIX-LISTEN:…,fork EXEC:<fake socket server>`. The test **unsets any
     inherited `HERDR_*` first**, so running it inside a live herdr pane
     can never reach the real server.
     - The fake herdr keeps its state in files. It logs every call. It
       answers `tab create` and `pane get` with the fields in the
       interface table. It runs `pane run` lines with `bash -c "<line>" &`.
       It can be told to fail a named subcommand, to drop the first `pane
       run`, or to change a pane's `terminal_id`.
   - **Cases**, each printing `ok <name>`:
     1. Outside herdr: stdin, stdout, stderr and exit codes 0, 3 and 124
        come through byte-identical.
     2. The same four through the pane path.
     3. `tab create` fails: the command runs exactly once (it counts its
        runs in a file).
     4. The runner never claims: the helper runs it once, and a late
        runner runs nothing.
     5. The pane vanishes mid-run: exit 1, the stderr message, the partial
        output replayed, no second run.
     6. The runner dies after its claim: the helper returns within 5 s
        (scaled), with 1 or 127, and does not hang.
     7. The first `pane run` is dropped: the resend runs it once.
     8. stdin is a terminal: under `script -qc` (util-linux), the command
        gets empty input and does not block.
     9. A fallback after the stdin was saved gets the full prompt.
     10. A changed `terminal_id` means no close or report was sent.
     11. Ctrl-C (SIGINT to the helper) kills the command's group: a
         `sleep 300` command is gone within the scaled 5 s.
     12. Two parallel runs: the second tab is inserted after the first.

   → Verify by `shellcheck home/development/herdr-run.sh home/development/herdr-run-test.sh`
   and by running
   `bash home/development/herdr-run-test.sh <wrapper>`, where `<wrapper>` is
   a two-line script running `bash -euo pipefail home/development/herdr-run.sh "$@"`.
   Every case prints `ok`. Step 2 runs the same test against the built tool.
   Traps:
   - The helper runs under `writeShellApplication`'s `set -euo pipefail`.
     Every herdr or socat call that may fail goes inside `if` or ends in
     `|| …`.
   - Replay output with `cat`, never via `$(...)`.
   - `mkdir` is the only claim. No `[ -e ]` then `touch`.
   - `kill -- -$pgid` only after the numeric check. An empty value would
     become `kill -1`, which kills every process of the user.
2. **`home/development/agent-run.nix` and `home/development/agent-run.sh`**
   (one coder).
   - In `agent-run.nix`, add a `let` binding `herdr-run =
     pkgs.writeShellApplication { name = "herdr-run"; runtimeInputs = with
     pkgs; [ jq socat coreutils util-linux procps ]; text = builtins.readFile
     ./herdr-run.sh; checkPhase = …; }`.
     - `checkPhase` replaces the default, so it must restate it:
       `runHook preCheck`, `${pkgs.stdenv.shellDryRun} "$target"`,
       `${lib.getExe pkgs.shellcheck} "$target"`, then the test, then
       `runHook postCheck`:

       ```nix
       testPath = lib.makeBinPath (with pkgs; [ bash coreutils util-linux procps jq socat gnugrep ]);
       # in checkPhase:
       PATH=${testPath}:$PATH bash ${./herdr-run-test.sh} "$target"
       ```

       Read the current nixpkgs `writeShellApplication`
       to copy its default check exactly, rather than trusting this line.
     - Add `herdr-run` to `home.packages` and to `agent-run`'s
       `runtimeInputs`.
   - In `agent-run.sh`, line 44 becomes `herdr-run agy agy-implement …` and
     line 49 becomes `herdr-run codex codex-implement …`.

   → Verify by `just test-host p620`. The check runs and passes, and
   `git diff home/development/agent-run.sh` shows exactly two changed lines.
   Traps:
   - `agent-run.nix` is already imported (`home/development/default.nix:17`).
     Do not add an import.
   - If the self-test cannot run in the sandbox, stop and report. Do not
     disable it.
3. **`home/development/claude-code-skills/second-opinion/SKILL.md`** and
   **`…/handoff/SKILL.md`**.
   - Prefix the four command blocks (`codex review`, `codex exec`, `agy`,
     `agy --agent`): `timeout … env -u …` becomes `herdr-run codex timeout
     … env -u …`.
   - Prefix the direct `agy-implement --model` line in `handoff`.
   - Add one sentence to each: *Inside herdr, each run shows as a `↳` row
     under this session; outside herdr, `herdr-run` just runs the command.*

   → Verify by comparing each guard string's count before and after:
   `git show HEAD:<file> | grep -cF -- '<guard>'` against
   `grep -cF -- '<guard>' <file>`, for `-s read-only`,
   `sandbox_mode="read-only"`, `--mode plan`, `env -u OPENAI_API_KEY`,
   `env -u GEMINI_API_KEY` and `forced_login_method=chatgpt`. Every count
   must be equal. Also check that `git diff` adds only the `herdr-run <label>`
   prefix to command lines, and run `npx markdownlint-cli2` on
   both files.
   Traps: the pre-push markdownlint lints whole files.
4. **Build** (mine): `just check-syntax`, `just test-host p620` and
   `just test-host razer` all succeed.
5. **`docs/applications/herdr.md`**: add a section, "Codex and agy rows",
   covering what shows, `herdr-run`, and what happens outside herdr. Nav is
   unchanged.
   → Verify by markdownlint on the file.
6. **Deploy and live check** (mine):
   - Read and post on `#agents:freundcloud.org.uk`, then `just quick-deploy
     p620`.
   - **Check:** a parallel second-opinion run on a trivial prompt shows two
     `↳` rows under the lead. Both are done for about 3 s, then their tabs
     close.
   - **Check:** the outputs match a run made outside herdr.
   - **Check:** Ctrl-C and `kill -9` on the helper leave **that run's**
     group empty: read `cmd.pgid` from its private directory first, then
     `pgrep -g <pgid>` is empty within 7 s.
   - **Check** on p620 and razer: `HERDR_BIN_PATH` is set in a fresh herdr
     pane, and `herdr-run` reaches it. If it is unset, the tool falls back
     to `herdr` on `PATH`.
   - **Check:** `agent-run codex` on a scratch worktree gives the same
     verdict.
   - razer through `just deploy-via-p620 razer` once you agree. Not p510.

   → Record the results in the PR.

## Tests

| Command | Expected |
|---|---|
| the self-test, in `checkPhase` | 18 `ok` lines, exit 0 |
| `just check-syntax`, then `just test-host p620` and `razer` | pass |
| live parallel review in herdr | two `↳` rows, outputs identical to a headless run |
| Ctrl-C and `kill -9` during a live run | the recorded `cmd.pgid` has no members (`pgrep -g <pgid>` empty) within 7 s, and that tab is gone |

## Rollback

Revert the PR. The behaviour change sits only behind the `herdr-run`
prefix. A stray tab from a failed run can be closed by hand, and it never
runs anything again.

## Deviations found during implementation

- **Live check (step 6), `kill -9` of the helper:** the watchdog sent TERM,
  the command ended, the runner exited, and its `EXIT` trap killed the
  watchdog mid-sleep, so the pane was never closed. Now the runner's `EXIT`
  trap closes the pane itself when the helper is gone (identity-checked).
  Self-test case 13, `helper-killed`, covers it (12 → 13 cases); it fails on
  the previous code.
- **TERM then KILL** waits only until the command's group is empty, up to
  5 s, instead of a fixed 5 s, so the tab closes as soon as the run is gone.
- Step 2 used `shellcheck-minimal` (the nixpkgs default's checker) and added
  `gawk` and `gnused` to `runtimeInputs`, which `herdr-run.sh` uses.
- **PR review fixes (Codex, agy and Opus reviews of #2659), cases 14–18:**
  - The runner, when signalled (its tab closed, Ctrl-C inside it), now stops
    the command's group first and writes `lost`, which the helper reports as
    a lost run (exit 1). Before, it wrote 127 while the command kept running,
    and `agent-run`'s retry could start a second implementer.
  - The runner keeps the group ID in memory, stops the group itself when it
    is orphaned, then removes the private directory and closes the pane.
  - Tab placement is one function called as `place_tab || :`, and every jq
    parse of a herdr reply is guarded, so an error reply cannot kill the
    helper before the run (it previously left a tab and ran nothing).
  - The headless fallback `exec`s the command, so a signal to `herdr-run`
    reaches it.
  - The environment is copied with one `declare -p` per exported name.
  - The wait loop ticks every second and needs two failed checks in a row
    before declaring a run lost; it re-checks `status` first.
  - SIGHUP is trapped like INT and TERM; the runner bakes in `herdr-run`'s
    own PATH.
  - Self-test: 13 → 18 cases. `runner-signalled`, `socket-error`,
    `headless-term` and `term-resistant-child` fail on the previous code.
