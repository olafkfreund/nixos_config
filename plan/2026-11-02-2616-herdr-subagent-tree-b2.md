---
status: draft
issue: 2616
spec: spec/2026-11-02-2616-herdr-subagent-tree.md
reviewers:
  - codex # the user asked for Codex and agy on this task; Codex found the fork's must-fixes
  - agy # the same request; agy was not obtained for the spike, so it reviews the code
---

# Plan: Phase B2, Claude teammates as herdr panes in a tree

This plan implements spec Addendum B2 (approved 2026-11-02). Phase A (the
swarm reaper) is live and unchanged except where step 4 extends it.

## Decisions carried from the approved spec

- **Package the fork** `rameshbaskaran/herdr-claude-teams` (MIT), pinned at
  `984b08235`, plus a local `ownership.patch`. Its tests run at build time.
- **Ownership:** the shim records each pane it creates (by `split-window`
  and `new-window`). `kill-pane` closes only owned panes. `kill-window` and
  `kill-session` become logged no-ops, exit 0.
- **The respawn race:** after the Ctrl-C, poll `pane.process_info` (≤ 2 s)
  until the placeholder `cat` has left the foreground, then type the command.
- **`select-layout`:** a no-op.
- **Shim from the store:** no runtime write to `~/.cache`.
- **Launch path:** a zsh `claude` function runs `herdr-claude-teams` only when
  `HERDR_ENV=1`; elsewhere it is plain `claude`.
- **Tree:** teammates are splits of the lead's tab, and herdr-radar already
  nests split panes. Each teammate pane gets the label `↳ <name>`. If radar
  does not nest them live, stop and go back to the user (the fallback is a
  projection, which is not in this plan).
- **Lingering:** the Phase A reaper also closes owned herdr panes that have
  been idle for `idleMinutes`. Only owned panes are touched.

## Refinement found while planning (within the spec)

The spec put the label in a new `$teammate` token rendered by the Claude row
template in `home/development/herdr.nix`. That template sits inside
herdr-radar's **frozen block**. Any edit there reads as stale, and radar's
daemon then retries an EROFS write on every start (memory:
herdr-radar-frozen-blocks). The label therefore goes through
`pane.report_metadata`'s **`title`** field instead (`"↳ alpha"`), which the
frozen template already renders through its `$title_*` tokens. `herdr.nix`'s
radar blocks stay byte-identical.

## Facts used

- The shim runs in the lead's env, which carries `HERDR_PANE_ID` (the lead's
  pane), `HERDR_SOCKET_PATH`, and `TMUX=<socket>,<pid>,herdr`.
- Claude 2.1.316 starts a teammate with `split-window … -- cat` and then
  `respawn-pane -k -t <pane> -- "cd … && env … claude --agent-id alpha@… --agent-name alpha …"`
  (spike `trace3.jsonl`).
- Teammates run in a plain herdr pane shell, so their hooks see
  `HERDR_PANE_ID` (the teammate's pane) and **no** `TMUX`.
- herdr 0.9.5 socket: one JSON line in, one out (`{"id","method","params"}`).
  - `pane.process_info {pane_id}` returns
    `foreground_processes[].argv`.
  - `pane.report_metadata` takes
    `{pane_id, source, title, …}`.
  - `pane.close {pane_id}`.
- Fork layout: `herdr_claude_teams/{verbs,launcher,shim,socket_client,…}.py`
  and `tests/` (pytest). `tests/test_live_smoke.py` needs a live herdr, so
  disable it in the build.
  - `verbs.py` handlers: `_split_window` (204), `_respawn_pane` (263),
    `_kill_pane` (405), `_kill_window` (413), `_select_layout` (468),
    `_new_window` (558), `_kill_session` (614).
  - `launcher.py`: `materialize_shim_dir`/`default_shim_dir` write the shim
    to `~/.cache`.
- `home/development/herdr.nix` takes `{ lib, ... }` today. HM modules reach
  local packages as `pkgs.customPkgs.<name>`, as in `claude-code-mcp.nix`.

## Steps

1. **`pkgs/herdr-claude-teams/{default.nix,ownership.patch}`: package
   and patch the fork.**
   - `python3Packages.buildPythonApplication`, `pyproject = true`, hatchling.
     `fetchFromGitHub` uses owner `rameshbaskaran`, repo `herdr-claude-teams`,
     the full rev of `984b08235`, and its hash.
   - `pytestCheckHook` with `disabledTestPaths = [ "tests/test_live_smoke.py" ]`.
   - Install `$out/libexec/herdr-claude-teams/shim/tmux` via
     `makeWrapper ${python.interpreter} … --add-flags "-m herdr_claude_teams.shim"`
     with the package's `PYTHONPATH`.
   - Wrap `bin/herdr-claude-teams` with
     `--set HERDR_CLAUDE_TEAMS_SHIM_DIR <that dir>`.

   The patch (a `git diff` against the pin):
   - a. **Ownership file.** It lives at
     `$XDG_RUNTIME_DIR/herdr-claude-teams/<HERDR_PANE_ID>.owned`, one line
     `<HERDR_SOCKET_PATH>\t<pane_id>` per pane. `_split_window` and
     `_new_window` append to it after a successful create.
   - b. **Destructive verbs.** `_kill_pane` closes only a pane listed in any
     `.owned` file with the same socket, then removes the line. Otherwise it
     makes a trace-logged no-op and returns 0. `_kill_window` and
     `_kill_session` make a trace-logged no-op and return 0.
   - c. **Respawn wait.** In `_respawn_pane` with `-k`, after the Ctrl-C,
     poll `pane.process_info` every 0.1 s for up to 2 s, until no foreground
     argv[0] basename is `cat`. Then send the command. On timeout, send it
     anyway and log it.
   - d. **`select-layout`.** `_select_layout` returns 0 at once.
   - e. **Label.** In `_respawn_pane`, take `--agent-name <n>` from the
     command. If present, call `pane.report_metadata`
     `{pane_id, source: "herdr-claude-teams", title: "↳ <n>"}`, wrapped in
     `try/except` so a failure never blocks the launch.
   - f. **Launcher.** `main()` uses `HERDR_CLAUDE_TEAMS_SHIM_DIR` when set and
     skips `materialize_shim_dir`.

   New tests in `tests/test_ownership.py` (they use the fork's
   `_fake_herdr.py`):
   - a foreign `kill-pane` is refused and an owned one closes;
   - `kill-window` and `kill-session` send no RPC;
   - respawn waits while `cat` is in the foreground and sends after;
   - `select-layout` sends no RPC;
   - the label call uses `↳ alpha`;
   - the launcher writes nothing when the env var is set.

   Register it in `pkgs/default.nix` next to `claude-swarm-reaper`.

   Verify by:
   `nix build .#nixosConfigurations.p620.pkgs.customPkgs.herdr-claude-teams -L`
   (the check phase runs). If that attribute path does not evaluate, build it
   the way the Phase A plan built `claude-swarm-reaper` (`just test-host p620`).

   Traps:
   - `pipefail` on `nix build | tail` (memory).
   - `ruff-format` pre-commit rewrites Python, so re-add and commit again.
   - No lambdas (E731).

2. **`home/development/herdr.nix`: install it and add the launch path.**
   - Change the args to `{ lib, pkgs, ... }`.
   - Add `home.packages = [ pkgs.customPkgs.herdr-claude-teams ];`.
   - Add `programs.zsh.initContent` with:

     ```zsh
     claude() {
       if [[ ${HERDR_ENV:-} == 1 && -n ${HERDR_SOCKET_PATH:-} ]]; then
         command herdr-claude-teams "$@"
       else
         command claude "$@"
       fi
     }
     ```

   Verify by: `just test-host p620`. In the built home, `zsh -ic 'whence -w claude'`
   prints `function`.

   Traps:
   - Do **not** touch any `# >>> herdr-radar … <<<` block. They must stay
     byte-identical.
   - In Nix strings, escape `${` as `''${`.
   - Check whether `initContent` or `initExtra` is what the repo's other zsh
     modules use (`home/shell/zsh.nix`), and match it.

3. **`pkgs/agent-say/agent_say.py` (+ test): teammates stay silent.**
   `interactive()` returns `False` when `HERDR_PANE_ID` is listed in any
   `$XDG_RUNTIME_DIR/herdr-claude-teams/*.owned` with the same
   `HERDR_SOCKET_PATH`. Add one test.

   Verify by: the package's `checkPhase` (`just test-host p620`).

   Traps: gates fail closed. A read error must mean "not a teammate", never
   an exception.

4. **`pkgs/claude-swarm-reaper/claude_swarm_reaper.py` (+ test) and
   `modules/programs/claude-swarm-reaper.nix`: reap idle owned herdr
   panes.**
   - **Hook.** When `TMUX` is unset and `HERDR_PANE_ID` is set, `idle`
     writes `record_root()/herdr/<pane>.json` = `{"ts", "socket"}`, and
     `active` removes it. In the module's `hookScript` shell guard:
     - add a `HERDR_PANE_ID` case;
     - `active` does a plain `rm -f` in shell (`PreToolUse` fires on every
       tool call, so no Python start);
     - `idle` execs the reaper.

     Replace `/` in the pane id with `_` for the file name.
   - **Reap.** A pure `decide_herdr(owned, records, now, idle_seconds)`
     returns `[(socket, pane)]` for owned panes whose record has the same
     socket and is old enough. `reap` closes each with a one-line JSON
     `pane.close` over the socket (stdlib `socket`), then removes the record
     and the `.owned` line. `--dry-run` logs only. A missing pane
     (`pane_not_found`) counts as done.
   - Add unit tests for `decide_herdr`: a foreign pane, a socket mismatch,
     too recent, idle.

   Verify by: the `checkPhase`, then `just test-host p620` and
   `just test-host razer`.

   Traps:
   - `shortcut:` comment that pane ids can repeat across herdr sessions, so a
     collision resets a record, which is the safe direction.
   - It stays a user unit (the existing comment says why).

5. **Deploy p620 and verify live.**
   - Bus `read_new`/`post`, then `AGENT_BUS_ANNOUNCED=1 just p620`. Check
     `/run/current-system` equals the eval'd toplevel and that no units
     failed.
   - In a **real** herdr pane: `claude`, then ask for two named teammates
     (alpha, beta), each doing a short task.
   - Expect:
     - two new panes in the lead's tab;
     - the sidebar shows them nested under the lead as `↳ alpha` and
       `↳ beta`;
     - shutdown closes both;
     - no narration from the teammates;
     - the trace shows no foreign `kill-pane` closing anything.
   - A second test: leave a teammate idle with `idleMinutes` temporarily
     low via `systemctl --user` run of `claude-swarm-reaper reap --idle-minutes 1`.
     The reaper closes it.
   - If radar does **not** nest them, stop and report to the user (spec
     fallback).

   Traps:
   - Bus guard: prose goes in files.
   - The user's own panes must stay untouched. Check `herdr` panes
     before and after.

6. **Deploy razer and repeat step 5's first check.**
   - `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`, with the same
     toplevel and failed-unit checks.

   Traps: razer `switch` exit 4 from syncthing is cosmetic (memory).
   Never touch p510.

## Tests

```bash
nix build .#nixosConfigurations.p620.pkgs.customPkgs.herdr-claude-teams -L
just test-host p620
just test-host razer
```

The fork's suite and the new ownership tests pass, as do the agent-say and
reaper suites. Both hosts build, and the live checks in steps 5 and 6 pass.

## Review

A fresh Opus agent gets this plan and `git diff origin/main`. Codex then
reviews with `codex review --base origin/main` (read-only), and agy with
`agy --mode plan` on the same diff, per `reviewers:`. Their findings are
advice: verify each before acting on it.

## Rollback

Revert the PR and redeploy. With the package and the zsh function gone,
`claude` is plain again: teammates fall back to in-process, and the reaper
keeps its Phase A behaviour.
