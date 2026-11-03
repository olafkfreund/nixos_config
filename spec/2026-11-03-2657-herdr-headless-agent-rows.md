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
   - the caller's stdin, if it is not a terminal, copied to `stdin`. A pipe
     or file is read in full first, so a large prompt never passes through
     the pane.
   - `env`, the caller's exported environment (`export -p`), and the cwd.
   - `run`, the runner script, with the arguments quoted by `printf '%q'`.
     The prompt in agy's `-p "$(cat ...)"` is already in the argument
     list, so it lives in this file and is never typed into the pane.
2. Under `flock` on `$XDG_RUNTIME_DIR/herdr-run-<lead tab>.lock`:
   - `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "↳ <label>" --no-focus`.
     Record the returned `pane_id`, `tab_id` and `terminal_id` at once.
   - Place the tab with the socket's `tab.move`, sent as one JSON line
     through `socat`. It goes right after the lead's tab and after any
     consecutive tabs whose label starts with `↳` (teammates or other
     runs), the same rule as #2633.

   The lock keeps parallel runs from computing the same position. A failed
   move is ignored: placement is cosmetic.
3. Wait for the new shell's prompt: `herdr pane wait-output <pane> --regex '\S' --timeout 10000`
   (any visible character), then 0.3 seconds more. Then run
   `herdr pane run <pane> "bash --noprofile --norc <dir>/run"`.
4. The runner, inside the pane:
   - **claims the run** with `mkdir <dir>/claim`. If that fails, the helper
     has already given up and is running the command itself, so the runner
     exits without running anything. This is the "each run happens exactly
     once" constraint.
   - sets the title with OSC 0 (`<label> review` or `<label> implement`,
     depending on the first word of the command).
   - restores the caller's environment with `env -i`, then sources `env`
     and `cd`s to the caller's cwd. The pane's own login environment never
     reaches the command.
   - runs the command in its own process group with `setsid`, with
     `< stdin`, and `tee`s stdout to `out` and stderr to `err`, so both
     also show in the pane.
   - writes the command's exit code (`PIPESTATUS[0]`) to `status.tmp`,
     renames it to `status`, and exits.

   While the command runs, a watchdog in the runner checks the helper's PID
   every 2 seconds. If the helper is gone (killed with SIGKILL, or Claude
   exited), the watchdog kills the command's process group and closes its
   own pane.
5. The helper, meanwhile:
   - waits up to 15 seconds for `claim` to be taken by the runner. If it is
     not, the helper takes `claim` itself and runs the command directly
     (headless, as today), then closes the pane it created. Whoever
     creates `claim` first runs the command, and only once.
   - once the runner has claimed, sends
     `herdr pane report-agent <pane> --source herdr-run --agent <label> --state working`,
     plus `report-metadata --token "split_mark=↳ <label>"` at about 2, 6
     and 15 seconds in the background. Before each send it checks that the
     pane's `terminal_id` is still the one recorded, the same check as
     `relabel.py`.
   - waits for `status`. Every 5 seconds it also checks that the pane still
     exists. If the pane is gone and `status` never came, the user closed
     the tab: the helper returns exit 1, with an explanation on stderr, and
     does not run the command again.
6. At the end, the helper:
   - copies `out` to its own stdout and `err` to its stderr, and keeps the
     exit code from `status`.
   - reports `--state idle` (herdr shows it as done), waits 3 seconds,
     then sends `release-agent` and `pane close` for the recorded pane only.
   - removes the private directory and exits with the code from `status`.

**Ctrl-C or SIGTERM to the helper:** a trap kills the runner's process group
and closes the recorded pane. The helper then exits 130 or 143, which is what
`timeout` and Bash callers already expect. A `timeout` placed inside the
wrapped command is unchanged: it fires inside the pane, and the exit code
comes back as 124.

**Any herdr call that fails** before the runner has claimed the run: the
helper takes `claim`, closes the pane if it created one, and runs the command
directly.

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
   - the pane disappears mid-run: exit 1, and no second run.
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
