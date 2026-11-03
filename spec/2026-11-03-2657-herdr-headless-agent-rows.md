---
status: draft
issue: 2657
intent: intent/2026-11-03-2657-herdr-headless-agent-rows.md
---

# Spec: Codex and agy runs show in the herdr sidebar under their Claude lead

## Design

### D1. One transparent wrapper: `herdr-run <label> <command> [args...]`

A new shell tool, `home/development/herdr-run.sh`, packaged the same way as
`agent-run` (`writeShellApplication` in `home/development/agent-run.nix`, with
`herdr`, `jq`, `socat`, `coreutils` and `util-linux` for `flock` and `setsid`).
Callers put it in front of the command they already run and change nothing
else:

```bash
herdr-run codex timeout 600 env -u OPENAI_API_KEY ... codex exec ... - < "$prompt"
```

To the caller it behaves exactly like the command it wraps: the same stdin,
stdout, stderr and exit code. So every existing redirection (`> file`,
`2>>"$log"`, `-o file`) and `agent-run`'s six result checks keep working
untouched. `<label>` is `codex` or `agy`. It is used for the row, the
`--agent` value and the tab label.

**Outside herdr**, when `HERDR_ENV` is not `1` or `HERDR_SOCKET_PATH` or
`HERDR_TAB_ID` is unset, the tool runs `exec "$@"` and nothing else.

### D2. Inside herdr: the run moves into a pane, its I/O stays the caller's

1. Make a private directory with `mktemp -d` (mode 0700). Write into it:
   - `stdin`, which is always created. It holds the caller's stdin read in
     full when stdin is a pipe or file, and is empty when stdin is a
     terminal. Claude's Bash tool never gives a terminal, so this only
     matters for a person typing the command. Both the pane run and the
     headless fallback read the command's input from this file, so a
     fallback after a herdr failure gets the same prompt.
   - `env`, the caller's exported environment (`export -p`), and the cwd.
   - `run`, the runner script, with the arguments quoted by `printf '%q'`.
     The prompt in agy's `-p "$(cat ...)"` is already in the argument
     list, so it lives in this file and is never typed into the pane.
2. Under `flock` on `$XDG_RUNTIME_DIR/herdr-run-<lead tab>.lock`:
   - `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "↳ <label>" --no-focus`.
     Record the returned `pane_id` and `tab_id`, then the pane's
     `terminal_id` from `herdr pane get`, at once. (The spike's `tab create`
     reply showed `root_pane.pane_id`, `tab_id` and `terminal_id`.)
   - Place the tab with the socket's `tab.move`, sent as one JSON line
     through `socat`. It goes right after the lead's tab and after any
     consecutive tabs whose label starts with `↳` (teammates or other
     runs), the same rule as #2633.

   The lock keeps parallel runs from computing the same position. A failed
   move is ignored: placement is cosmetic.
3. **Start the runner with a handshake, not a prompt guess.** The helper
   sends `herdr pane run <pane> "bash --noprofile --norc <dir>/run"` and
   waits 3 seconds for `<dir>/claim`. With no claim, it sends the same line
   again, up to 3 times (about 10 seconds). A line sent before the shell is
   ready is lost, and a copy that arrives late finds `claim` taken and exits
   at once, so resending is safe.
4. The runner, inside the pane:
   - **claims the run** with `mkdir <dir>/claim`. If that fails, the helper
     or an earlier copy already owns the run, so this copy exits without
     running anything. This is the "each run happens exactly once"
     constraint.
   - **right after claiming**, writes its PID to `runner.pid` and sets an
     `EXIT` trap. Whatever goes wrong after this point (a failed `cd`, a
     bad `env` file, the command not found), the trap writes a `status`:
     the command's code if it ran, else 127. The helper never waits on a
     claimed run that cannot finish.
   - sets the title with OSC 0 (`<label> review` or `<label> implement`,
     depending on the first word of the command).
   - restores the caller's environment with `env -i`, then sources `env`
     and `cd`s to the caller's cwd. The pane's own login environment never
     reaches the command.
   - starts the command with `setsid`, so it leads its own process group,
     and writes that group's ID to `cmd.pgid` before waiting on it. It
     reads `< stdin`, and its stdout and stderr are `tee`d to `out` and
     `err`, so both also show in the pane.
   - writes the exit code (`PIPESTATUS[0]`) to `status.tmp` and renames it
     to `status`.

   While the command runs, a watchdog in the runner checks the helper's PID
   every 2 seconds. If the helper is gone (killed with SIGKILL, or Claude
   exited), the watchdog sends SIGTERM to the group in `cmd.pgid`, then
   SIGKILL 5 seconds later, and closes its own pane.
5. The helper, meanwhile:
   - if no copy claimed the run after the third send, takes `claim` itself.
     If that succeeds, it runs the command directly (headless, as today,
     with `< stdin` from the private directory), then closes the pane it
     created. Whoever creates `claim` first runs the command, and only
     once.
   - once the runner has claimed, sends
     `herdr pane report-agent <pane> --source herdr-run --agent <label> --state working`,
     plus `report-metadata --token "split_mark=↳ <label>"` at about 2, 6
     and 15 seconds in the background.
   - waits for `status`. Every 5 seconds it also checks that the pane still
     exists and that `runner.pid` is alive. If either is gone and `status`
     never came, the run was lost (the user closed the tab, or the runner
     died). The helper sends SIGKILL to the group in `cmd.pgid` if any
     member is left, replays whatever `out` and `err` hold, and returns
     exit 1 with an explanation on stderr. It does not run the command
     again.
6. At the end, the helper:
   - copies `out` to its own stdout and `err` to its stderr, and keeps the
     exit code from `status`.
   - reports `--state idle` (herdr shows it as done), waits 3 seconds,
     then sends `release-agent` and `pane close`.
   - removes the private directory and exits with the code from `status`.

**Every report, release and close checks identity first.** Before any
`report-agent`, `report-metadata`, `release-agent` or `pane close`, in the
helper and in the watchdog, the code calls `herdr pane get` and acts only if
the pane's `terminal_id` is still the one recorded at creation. This is the
same check as `relabel.py`. A pane ID reused after a herdr restart is never
touched.

**Ctrl-C or SIGTERM to the helper:** a trap sends SIGTERM to the group in
`cmd.pgid` (the command itself, not just the runner), then SIGKILL 5 seconds
later. It then closes the pane and exits 130 or 143, which is what `timeout`
and Bash callers already expect. A `timeout` placed inside the wrapped
command is unchanged: it fires inside the pane, and the exit code comes back
as 124.

**Any herdr call that fails** before a runner has claimed the run: the
helper takes `claim`, closes the pane if it created one, and runs the command
directly with `< stdin`.

**Output timing.** The caller receives stdout and stderr when the run ends,
not while it runs, on every path: success, failure, lost run. Every caller in
D3 sends its output to files or `$(...)` and reads it only after the command
exits, so none of them notices. The live view is the pane.

### D3. Callers

- **`second-opinion`**
  (`home/development/claude-code-skills/second-opinion/SKILL.md`): put
  `herdr-run codex` or `herdr-run agy` in front of the four command blocks
  (`codex review`, `codex exec`, `agy` and `agy --agent`; the consensus
  runs reuse them). Add one sentence: inside herdr, each run shows as
  a row under the lead, and outside herdr nothing changes.
- **`home/development/agent-run.sh`**: lines 44 and 49 call
  `herdr-run agy agy-implement ...` and `herdr-run codex codex-implement ...`.
  The retry loop stays around the wrapper, so a retry is a second, visible
  run with its own row.
- **`handoff`**
  (`home/development/claude-code-skills/handoff/SKILL.md`): the direct
  `agy-implement --model <name>` example gets the same prefix.

`herdr.nix` needs no change. Codex and agy rows use the default
`[ui.sidebar.agents].rows`, which already renders `$split_mark`, the logo
and the state.

## Alternatives rejected

- **A placeholder pane driven only by `report-agent`, with the run left
  headless:** the row would not show the run's real output, and its state
  could drift from the process. It needs the same pane lifecycle as D2 for
  less benefit.
- **A row with no pane:** herdr's socket API has no method that creates
  one. Every `report_*` method takes an existing `pane_id`, and the
  `agent.view.*` methods only order rows (spec #2616).
- **Extending herdr-claude-teams (Python) instead of a shell tool:** that
  package is a tmux shim on top of a pinned fork with two patches already.
  A third, unrelated caller would make every rebase harder. The new tool
  only needs a single `tab.move` JSON line, which `socat` sends.
- **Passing the exit code through `pane wait-output`:** it matches screen
  text, so it cannot tell success from failure (spike).
- **Typing the command and prompt into the pane:** agy prompts reach about
  100 KB, and text sent before the shell is ready is lost (spike).
- **Keeping the tab open after the run:** the output is already in the
  lead's files. A 3-second done state is what the intent asks for.
- **Waiting for the shell prompt before sending the command:** any visible
  character can match startup text, so it is a timing guess. The `claim`
  handshake with resends (D2 step 3) does not depend on timing.
- **A narrower launcher per caller, taking a prompt file and an output
  path** (suggested in Codex's review): it would rewrite every command block
  in both skills and in `agent-run`, and each rewrite risks touching a
  safety guard. The transparent wrapper leaves those lines as they are,
  apart from a prefix. The stdin, output and process-group cases that made
  it look risky are pinned down in D2.

## Risks

- **Interleaving of stdout and stderr changes** for callers that merge
  them (`agent-run`: `>>"$log" 2>&1`). The content is identical, but stdout
  is replayed before stderr instead of interleaved. `agent-run`'s checks
  read the result files, not the order of the log.
- **A different environment inside the pane** if `export -p` misses
  something, such as non-exported shell variables. The commands are external
  programs and only see exported variables, so they get the same view. The
  `env -u` guards are in the argument list and still apply inside the pane.
- **An orphan tab** if the helper and the pane's runner are both killed
  before cleanup (for example, the herdr server restarts). Its row shows
  idle or unknown until the user closes it. This does not run anything
  twice.
- **Radar changes upstream** could drop `split_mark` again. The row would
  still show as a `codex` or `agy` agent, just without the `↳` mark.
- **Hosts:** p620 and razer. On p510 the tool is installed but stays
  dormant unless Claude runs inside herdr there. Deploying p510 needs your
  approval, as always.

## Verification

1. `just check-syntax`, `shellcheck` (through `writeShellApplication`), and
   `just test-host p620` and `just test-host razer` build.
2. A self-test, `home/development/herdr-run-test.sh`, run in the package's
   `checkPhase`. It uses a fake `herdr` on `PATH` that records its calls
   and can be told to fail. The cases:
   - outside herdr: stdin, stdout, stderr and the exit code (0, 3, 124)
     pass through byte for byte.
   - inside the fake herdr: the same four come through the pane path, and
     only the recorded pane is closed.
   - `tab create` fails: the command runs exactly once, headless.
   - the runner never claims: the helper claims and runs it once, and the
     late runner then exits without running it (`claim` race).
   - the pane disappears mid-run: exit 1, the partial output is replayed,
     and there is no second run.
   - the runner dies after claiming (its `cd` fails, or it is killed):
     the helper returns within 5 seconds, with 127 or 1, and does not hang.
   - the first `pane run` line is dropped: the resend starts the runner,
     and the command runs once.
   - stdin is a terminal: the command gets empty input and does not block.
   - herdr fails after the stdin was saved: the headless fallback gets the
     full prompt.
   - a recorded pane ID whose `terminal_id` changed is never reported to
     or closed.
3. Live on p620, in this herdr session:
   - a parallel second-opinion run shows `↳ codex` and `↳ agy` under the
     lead.
   - both show done for about 3 seconds and then their tabs close.
   - the lead's `codex.md` and `agy.json` match a run made outside herdr.
4. Live: Ctrl-C during a run stops the `codex` process (`pgrep` finds
   none) and closes its tab. `kill -9` on the helper does the same within
   about 2 seconds, through the watchdog.
5. `agent-run codex <prompt>` on a scratch worktree: one row, and the same
   six-check verdict as without herdr.
