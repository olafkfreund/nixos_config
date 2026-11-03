---
status: draft
issue: 2657
spec: spec/2026-11-03-2657-herdr-headless-agent-rows.md
coders:
  1: codex   # herdr-run.sh is small, tricky logic: the claim race, traps, process groups
  2: coder   # the self-test is straightforward shell against a fake herdr
  3: coder   # one Nix file, packaging plus checkPhase
  4: coder   # two one-line prefixes in agent-run.sh
  5: agy     # mechanical prefix edits across two SKILL.md files
  7: coder   # a docs section
reviewers:
  - codex    # it designed with us; checks the diff matches its findings
  - agy      # independent read; was not obtained on the spec
---

# Plan: Codex and agy runs show in the herdr sidebar under their Claude lead

## Approved decisions (from the spec)

- A new tool, `herdr-run <label> <command> [args...]` (`<label>` is `codex`
  or `agy`). It is transparent to the caller: same stdin, stdout, stderr and
  exit code. Callers only add the prefix.
- Outside herdr (`HERDR_ENV` is not `1`, or `HERDR_SOCKET_PATH` or
  `HERDR_TAB_ID` is unset): `exec "$@"` and nothing else.
- Inside herdr:
  - **Private directory** from `mktemp -d` (0700) holding:
    - `stdin`: always created. It holds the caller's stdin read in full,
      or is empty when stdin is a terminal.
    - `env`: the caller's environment from `export -p`, plus the cwd.
    - `run`: the runner, with the arguments quoted by `printf '%q'`.
  - **Tab:** under `flock` on `$XDG_RUNTIME_DIR/herdr-run-<lead tab>.lock`,
    run `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD"
    --label "↳ <label>" --no-focus`. Record `pane_id`, `tab_id` and
    `terminal_id`, then place the tab with the socket's `tab.move`, sent
    as one JSON line through `socat`. A failed move is ignored.
  - **Start handshake:** send `herdr pane run <pane> "bash --noprofile
    --norc <dir>/run"`, then wait 3 s for `<dir>/claim`. Resend up to 3
    times. A late copy finds `claim` taken and exits.
  - **Runner:**
    1. `mkdir claim`. If it fails, exit without running anything.
    2. Write `runner.pid` and set an `EXIT` trap that always writes
       `status` (127 if the command never ran).
    3. Set the title with OSC 0.
    4. Restore the environment with `env -i` plus `env`, then `cd`.
    5. Start the command with `setsid`, writing its group to `cmd.pgid`,
       with `< stdin`, and `tee` stdout to `out` and stderr to `err`.
    6. Write `PIPESTATUS[0]` to `status.tmp`, then `mv` it to `status`.

    A watchdog checks the helper's PID every 2 s. If the helper is gone, it
    sends TERM to the group, KILL 5 s later, and closes its own pane.
  - **Helper:**
    - If no copy has claimed after the third send, it claims itself and
      runs the command headless with `< stdin`.
    - Once a runner has claimed:
      - `report-agent --source herdr-run --agent <label> --state working`.
      - `split_mark=↳ <label>` sent at about 2, 6 and 15 s.
      - Wait for `status`, checking every 5 s that the pane exists and
        `runner.pid` is alive. If either is gone, KILL the group, replay
        the partial output and exit 1. Never run the command again.
    - At the end:
      1. Replay `out` to stdout and `err` to stderr.
      2. Report `idle`, wait 3 s, then `release-agent` and `pane close`.
      3. Remove the directory and exit with the code from `status`.
  - **Before every report, release and close:** `herdr pane get` must show
    the recorded `terminal_id`. Otherwise do nothing.
  - **Ctrl-C or SIGTERM to the helper:** TERM to `cmd.pgid`, KILL 5 s
    later, close the pane, exit 130 or 143.
  - **Any herdr failure before a claim:** claim, close the pane if one was
    created, and run headless with `< stdin`.
- Callers:
  - `second-opinion`: the `codex review`, `codex exec`, `agy` and
    `agy --agent` blocks.
  - `agent-run.sh`: lines 44 and 49, with the retry loop outside the
    wrapper.
  - `handoff`: the direct `agy-implement --model` example.
- `herdr.nix` is unchanged.

### Deviation from the spec (found while writing this plan)

The spec places the tab "after any consecutive tabs whose label starts with
`↳`". That cannot work: the auto-title plugin rewrites tab labels (live
`tab.list` on 2026-11-03 showed `2 · agy`, `1 · nixos › claude › …`).
Instead, a tab counts as a child row when its root pane carries a
`split_mark` token, which is what the sidebar actually draws from. This
covers herdr-run tabs and herdr-claude-teams teammates alike. The `--label`
stays: it is what the tab shows until auto-title replaces it.

## Steps

1. **`home/development/herdr-run.sh`** (new): the helper and runner from
   the decisions above. The runner is written into the private directory
   as a here-doc, with the quoted command and the private paths baked in.
   - Read `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID` and `HERDR_SOCKET_PATH` once
     at the start. Call herdr as `"${HERDR_BIN_PATH:-herdr}"`: herdr sets
     `HERDR_BIN_PATH` in every pane, to the binary of the running server. The socket call is `printf '%s\n' "$json" | socat -t5 -
     UNIX-CONNECT:"$HERDR_SOCKET_PATH"`.
   - **Insert position:** list the tabs with socket `tab.list`. Start right
     after the lead's index, then skip each following tab whose root pane
     has `.tokens.split_mark`, read with `herdr pane get` for that tab's
     first pane from `pane.list`.
   - The OSC title is `<label> implement` when the command contains
     `-implement`, else `<label> review`.

   → Verify by `shellcheck home/development/herdr-run.sh` and by step 2.
   Traps:
   - It runs under `writeShellApplication`, so `set -euo pipefail` is on.
     Every herdr call that may fail must be inside `if` or end in `|| …`,
     or `-e` kills the helper mid-run.
   - Do not use `$(...)` to capture the command's output: it would drop the
     trailing newline. Replay with `cat`.
   - `mkdir` is the only atomic claim. Do not use `[ -e ]` then `touch`.
2. **`home/development/herdr-run-test.sh`** (new): a self-test. It puts a
   fake `herdr` and `socat` on `PATH`. The fake records its calls in a
   log, can be told to fail a named subcommand, and runs `pane run`
   commands with `bash -c … &`. One delay setting makes the first
   `pane run` vanish.
   - **Cases**, from spec Verification 2:
     - outside herdr, byte-identical stdin, stdout, stderr and exit codes
       0, 3 and 124
     - the same four through the pane path
     - `tab create` fails, so the command runs headless exactly once (it
       counts its runs in a file)
     - the runner never claims, so the helper runs it once and a late
       runner runs nothing
     - the pane vanishes mid-run: exit 1, partial output replayed, no
       second run
     - the runner dies after its claim: the helper returns within 7 s and
       does not hang
     - the first `pane run` is dropped, so the resend runs it once
     - stdin is a terminal (`script -qc`, or skip it with a printed reason
       if unavailable)
     - a fallback after the stdin was saved gets the full prompt
     - a changed `terminal_id` means no close or report was sent

   → Verify by `bash home/development/herdr-run-test.sh ./result/bin/herdr-run`
   printing one `ok` per case and exiting 0.
   Traps: in the sandbox, `XDG_RUNTIME_DIR` is unset, so the test sets it
   to a temp dir. Keep each case under 20 s, so sleeps scale through
   `HERDR_RUN_TEST_SPEED` (an environment variable read only by the test's
   fake, never by `herdr-run`).
3. **`home/development/agent-run.nix`**: add a second
   `writeShellApplication`, `herdr-run`:
   - `runtimeInputs = [ jq socat coreutils util-linux procps ]`. herdr is
     deliberately not included: the tool only calls it inside herdr, through
     `HERDR_BIN_PATH`, so p510 does not gain herdr in its closure.
   - Extend `checkPhase` to run the default shellcheck, then
     `bash ${./herdr-run-test.sh} "$target"`.

   → Verify by `nix build .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.path`
   (or `just test-host p620`) with the check passing.
   Traps:
   - Explicit imports only: `agent-run.nix` is already imported, so do not
     add a new import.
   - If the test cannot run in the sandbox, stop and report rather than
     disabling it.
4. **`home/development/agent-run.sh`**: line 44 becomes `herdr-run agy
   agy-implement …` and line 49 becomes `herdr-run codex codex-implement
   …`. Nothing else changes.
   → Verify by `shellcheck`, and `git diff` showing exactly two changed
   lines.
   Traps: `agent-run`'s `runtimeInputs` must now include the `herdr-run`
   package. Reference it as a let-binding shared in `agent-run.nix`, not
   via PATH luck.
5. **`home/development/claude-code-skills/second-opinion/SKILL.md`** and
   **`…/handoff/SKILL.md`**:
   - Prefix the `codex review`, `codex exec`, `agy` and `agy --agent`
     commands with `herdr-run codex` or `herdr-run agy`. That is `timeout
     … env -u …` becoming `herdr-run codex timeout … env -u …`.
   - Prefix the direct `agy-implement --model` line in `handoff`.
   - Add one sentence to each: *Inside herdr, each run shows as a `↳`
     row under this session; outside herdr, `herdr-run` just runs the
     command.*

   → Verify by `git diff` showing the guards (`-s read-only`, `-c
   sandbox_mode="read-only"`, `--mode plan`, `env -u`,
   `forced_login_method`) byte-identical, and `just check-syntax`.
   Traps: the pre-push markdownlint lints whole files. Run it before
   pushing.
6. **Build** (mine): `just check-syntax`, `just test-host p620`, and
   `just test-host razer` (razer builds on p620 via
   `just deploy-via-p620 razer` only at deploy time).
   → All three succeed.
7. **`docs/applications/herdr.md`**: add a section, "Codex and agy rows",
   covering what shows, `herdr-run`, and what happens outside herdr. Nav
   is unchanged.
   → Verify by markdownlint on the file.
8. **Deploy and live check** (mine):
   - Announce on `#agents:freundcloud.org.uk`, then `just quick-deploy
     p620`.
   - Then spec Verification 3–5: a parallel second-opinion run on a
     trivial prompt shows both rows under the lead, done for about 3 s,
     then the tabs close. The outputs match a run made outside herdr.
     Ctrl-C and `kill -9` leave no `codex` process. `agent-run codex` on
     a scratch worktree gives the same verdict.
   - razer through `just deploy-via-p620 razer` after you agree. p510 is
     not deployed.

   → Record the results in the PR.

## Tests

| Command | Expected |
|---|---|
| `bash home/development/herdr-run-test.sh <built herdr-run>` | one `ok` per case, exit 0 |
| `just check-syntax` and `just test-host p620` / `razer` | pass |
| live parallel review in herdr | two `↳` rows, outputs identical to a headless run |
| Ctrl-C and `kill -9` during a run | `pgrep -f 'codex exec'` empty within 7 s, tab gone |

## Rollback

Revert the PR. The only behaviour change sits behind the `herdr-run`
prefix, and removing the prefix restores today's headless runs. A stray tab
left by a failed run can be closed by hand. It never runs anything again.
