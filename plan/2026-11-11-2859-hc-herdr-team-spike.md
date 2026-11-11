---
status: draft
issue: 2859
spec: spec/2026-11-11-2859-hc-herdr-team-spike.md
# coders: none. No step edits repo files. The spike script lives in /tmp,
#   and running it and its live checks stay with the lead.
reviewers:
  - codex    # read the spike script before it runs (isolation, cleanup)
  - agy      # second read of the script; found the holder-core risk class
---

# Plan: spike — one Codex review through an isolated hc core

## Approved decisions

- **Scope:** Codex only, on p620 only. Results go in a comment on #2859. No
  repo, module or host change, and no deploy. The script is attached to the
  comment, not committed.
- **Never touch the owner's core:** never run a bare `hc` (even `hc ls`
  starts the owner's core), and never stop or restart it.
- **Isolation:** every `hc` call goes through `hcx`, which starts through
  `agent-env` (an allowlist: PATH, HOME, LANG, TERM, XDG_*, USER, …), so
  the core starts without tokens. Any inherited `HC_SOCKET` is unset.
- **Codex:** every Codex command also starts through `agent-env`, unsets the
  seven API-key variables (`OPENAI_API_KEY`, `OPENAI_API_KEY_FILE`,
  `GEMINI_API_KEY`, `GEMINI_API_KEY_FILE`, `GOOGLE_API_KEY`,
  `ANTHROPIC_API_KEY`, `ANTHROPIC_API_KEY_FILE`), and runs with
  `--no-daemon` and `-c forced_login_method=chatgpt`.
- **Read-only:** `git status --porcelain` is empty before and after, in the
  run worktree `../nixos-2859-run`, which is kept until the end.

## The script

The script lives at `/tmp/claude-1000/hc-spike-2859.sh`, outside `$spike` so
cleanup doesn't delete it.

- **Phases:** it takes one argument, `0`, `1` … `11` or `cleanup`, and runs
  only that phase. Each phase writes to `$spike/out/<nn>-<name>`.
- **Errors:** it uses `set -uo pipefail`, without `-e`. Expected non-zero
  `hc` exits are recorded, not fatal: `7` needs_target, `124`/timeouts,
  the `false` template.
- **Core PID:** after phase 0, every phase first checks that the spike core
  PID (saved in `$spike/core.pid`) is still the core that
  `hcx server status --json` reports. If not, it exits; phase 7 saves the
  new PID itself.

```bash
spike=/tmp/claude-1000/hc-spike-2859
hcx() {
  agent-env env -u HC_SOCKET HC_SESSION=spike2859 \
    XDG_CONFIG_HOME="$spike/config" XDG_DATA_HOME="$spike/data" \
    XDG_STATE_HOME="$spike/state" XDG_CACHE_HOME="$spike/cache" hc "$@"
}
```

## Steps

1. **Write the script (lead).** Write the phases below. Check: `bash -n` and
   `shellcheck` are clean.
   Traps:
   - `HC_SESSION` must be set inside the `env` after `agent-env`, since its
     allowlist drops it;
   - `hc run` prints text unless `--json`, and `read`/`get` need a target
     ID;
   - create `$spike/turns` with `mkdir -m 700` (the sink insists on 0700,
     `herdr-team.sh:411`);
   - quote every `$spike` path.

   **Phase 0, isolation, before any terminal exists:**
   1. `mkdir -p` the `$spike` folders. Record the owner's state:
      `systemctl --user list-units --all 'herdr*' 'hc*'` and
      `pgrep -a herdr-core`, into `out/00-owner-before`.
   2. `hcx server start`, then `hcx server status --json` into
      `out/00-status`.
   3. The new core PID is the `herdr-core` PID in `pgrep` now that wasn't in
      step 1. Exactly one must exist; save it to `$spike/core.pid`.
   4. Check its `/proc/<pid>/environ`:
      - `HC_SESSION=spike2859`;
      - no `NIX_CONFIG` holding `access-tokens`, and none of the seven
        API-key variables.
   5. Its socket (from `server status`, or `ss -xlp | grep <pid>`) differs
      from any socket the owner's core PIDs listen on.
   6. The owner's units and PIDs are unchanged.
   7. **On any failure:** if `server status` named `spike2859` and the
      socket check passed, run `hcx server stop`. Otherwise kill only the
      PID from step 3 (`kill`, then `kill -9` after 5 s). Never stop
      anything else. Write `out/00-FAILED` and exit 1.

   **Phase 1, templates**, in `$spike/config/herdr-core/templates/`. Each
   is a `.md` file with frontmatter `name`, `description` and `command`
   (YAML folded `>-`, single-quoting each `-c` value), and a body that says
   read-only, no subagents, do not modify anything.
   - `spike-echo`: `printf '%s\n'` with the same two `-c` values as below.
     Run it (`hcx run --bg --json --name spike-echo spike-echo`), then
     `hcx read <id>`. Check the quotes survive; if not, fix the quoting
     before going on.
   - `spike-review`:

     ```text
     agent-env env -u <the seven> codex --no-daemon
       --dangerously-bypass-approvals-and-sandbox -c forced_login_method=chatgpt
       -c 'notify=["<sink>","<spike>/turns"]'
       -c 'projects={"<run>"={trust_level="trusted"},"<repo>"={trust_level="trusted"}}'
     ```

     `<sink>` is `$(readlink -f $(which herdr-team-sink))`. `<run>` is the
     run worktree and `<repo>` its main checkout (both trust entries are
     needed for a linked worktree, `herdr-team.sh:422-425`).
   - `spike-untrusted`: the same command without the `projects` entry.
   - `spike-false`: `false`.
   - `spike-scope`:
     `systemd-run --user --scope --quiet --collect -- bash -c 'sleep 30'`.

   `hcx templates --json` must list all five.

   **Phase 2, review.** First `git worktree add ../nixos-2859-run --detach
   origin/main` and `git status --porcelain` there (must be empty). Then
   `hcx run --bg --json --name spike-review --cwd <run> spike-review "<P>"`,
   where P is: "Review `home/development/herdr-team.sh` lines 570-590 for
   bugs. Report findings ranked by severity." Save the ID and
   `first_message.sent`. If it is false, save `hcx read <id>`.

   **Phase 3, waiting:** up to 15 rounds of
   `hcx wait <id> --timeout 60 --json`. Each round, record the status and
   whether a turn file is in `$spike/turns`. Stop on `done`/`idle` or a
   turn file.

   **Phase 4, the answer, three ways:** `hcx read <id> --lines 400`, the turn
   file, and `hcx get <id> --json`. Note completeness, duplicates and screen
   chrome.

   **Phase 5, environment:** the Codex PID (a child of the terminal) and its
   `/proc/<pid>/environ`, checked as in phase 0 step 4.

   **Phase 6, lead outside `hc`:**
   - `hcx get <id> --json` (its `parent`);
   - `hcx wait --children all --timeout 5` (record the exit and message);
   - `hcx run --bg --json --name spike-holder bash`. Then `hcx send` it one
     line with the full `hcx` environment prefix, `hc server status --json >
     $spike/out/06-holder-status`. Only if that names `spike2859`, send
     `<prefix> hc run --bg --name spike-child sleep 600`. Then
     `hcx kill spike-holder`, wait 5 s, and record whether `spike-child`
     still runs. If not `spike2859`, skip and record why.

   **Phase 7, restart:** `hcx server restart`. Check `spike-review` still
   exists. Save the new core PID (`pgrep` diff against the owner list) and
   its environ. `hcx run --bg --json --name spike-post bash`, and check that
   terminal's environ.

   **Phase 8, failures:**
   - `hcx run --bg --json --name spike-false spike-false`, then
     `hcx get`: exit code and state;
   - `hcx run --bg --json --name spike-sleep sleep 60`, then
     `hcx wait spike-sleep --timeout 5`: what a timeout reports;
   - `hcx run --bg --json --name spike-trust --cwd "$(mktemp -d -p "$spike")"
     spike-untrusted "say hi"`, then after 20 s: `first_message.sent`, status
     (`blocked`?) and the screen. Then `hcx kill` it.

   **Phase 9, containment:** `hcx run --bg --json --name spike-scope
   spike-scope`. While it runs, `systemctl --user list-units --type=scope`
   shows its scope. After 30 s, `hc get` shows the exit code, and the scope
   is gone. The `codex-implement` guard preflight in a template is **not**
   run (it writes); it stays unverified.

   **Phase 10, naming:** `hcx run --bg --json --name 2859 sleep 5` and
   `--name t2859 sleep 5`, recording whether each is accepted. Then
   `hcx get t2859 --json`: which terminal it resolves to.

   **Phase 11, herdr-team side**, in `<run>`: `herdr-team up t2859 review`,
   `herdr-team ask t2859 review <file with P>`, then
   `herdr-team down t2859`. Record setup, `answer`, outcome and time.
   Then `git status --porcelain` in `<run>` (must be empty).

   **Phase cleanup:**
   1. `hcx kill` and `hcx rm` every `spike-*`, `2859` and `t2859` terminal.
   2. `hcx server status --json`. Only if it names `spike2859`, run
      `hcx server stop`; otherwise kill the saved core PID.
   3. Kill any process that is in the core process trees recorded in phases
      0 and 7, or has `HC_SESSION=spike2859` in its environ (by PID).
   4. `git worktree remove ../nixos-2859-run`, then `rm -rf "$spike"`. The
      output is first copied to `/tmp/claude-1000/hc-spike-2859-out`.
   5. Re-record the owner's state into that output folder.
2. **Review the script (lead, with `reviewers:`).** Codex and agy read the
   script and this plan, read-only. Check `git status --porcelain` before and
   after. Fix what holds up.
3. **Announce (lead).** `read_new("#agents:freundcloud.org.uk")`, then post:
   an isolated `hc` core spike on p620, about 30 min, owner core untouched.
4. **Phase 0 only (lead).** Read `out/00-*`. If `00-FAILED`: run cleanup,
   comment the finding on #2859, and stop (the answer is "can't isolate").
5. **Phases 1-11 (lead)**, one at a time, reading each output before the
   next. A failed phase is recorded and the run goes on. The exception is a
   core-PID or isolation failure: then run cleanup and stop.
6. **Cleanup (lead).** Run the cleanup phase. Check:
   - the owner's before/after state is identical;
   - no `HC_SESSION=spike2859` process is left;
   - `$spike` and `<run>` are gone.
7. **Report (lead).** Comment on #2859 with:
   - versions (`hc`, Codex, herdr) and the script;
   - a comparison table (setup, answer, status, failures, cleanup, our
     lines of code);
   - the six "to find out" answers, each marked verified or unverified;
   - the owner's state before and after;
   - a recommendation limited to what was shown.

   If the recommendation is to adopt part of `hc`, open the follow-up issue.
   Post the gotchas on the bus. Close #2859.

## Tests

| Check | Expected |
|---|---|
| `bash -n`, `shellcheck` on the script | clean |
| phase 0 | one new core, `HC_SESSION=spike2859`, no tokens, its own socket, owner unchanged |
| `git status --porcelain` in `<run>`, before and after | empty |
| owner `pgrep -a herdr-core` and unit list, before and after | identical |
| spike processes after cleanup | none |

## Rollback

Nothing in the repo or on the hosts changes. To abort at any point, run the
cleanup phase. If `$spike` is already gone, kill the PIDs saved in
`/tmp/claude-1000/hc-spike-2859-out`, and any process with
`HC_SESSION=spike2859`.
