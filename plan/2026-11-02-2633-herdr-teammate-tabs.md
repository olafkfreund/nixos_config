---
status: draft
issue: 2633
spec: spec/2026-11-02-2633-herdr-teammate-tabs.md
---

# Plan: Claude teammates open in a new herdr tab

## Decisions carried from the approved spec

- **Tabs only:** no split/tab switch.
- **Creating the tab:** `split-window` resolves the target pane (`-t`, else
  `TMUX_PANE`) with `pane.get` to find the lead's `tab_id` and
  `workspace_id`. It then calls `tab.create {workspace_id, cwd (-c), focus: false}`.
  Focus is never taken.
- **Placing it:** `tab.move {tab_id, insert_index}` puts the tab right
  after the lead's tab, in spawn order. The index is the lead tab's
  position in a fresh `tab.list` + 1 + the number of owned tabs that
  directly follow it. A failed move is logged and not fatal.
- **Ownership:** `ownership.record(root_pane)`, as `new-window` does. The
  `.owned` format is unchanged.
- **Command and output:** a trailing command still goes through
  `pane.send_text`. `-P` still prints the root pane in tmux form.
- **Resize:** `resize-pane` on a pane that is alone in its tab is a logged
  no-op with exit 0.
- **Closing:** goes through the existing `kill-pane` and the reaper's
  `pane.close`. If herdr leaves an empty tab, close it with `tab.close`
  after the same `terminal_id` check, and make the same change in
  `pkgs/claude-swarm-reaper`.
- **Tab label:** set to `↳ <name>` with `tab.rename`, in the relabel path
  that sends `split_mark`.
- **Patch:** everything lands as `pkgs/herdr-claude-teams/teammate-tabs.patch`,
  applied after `ownership.patch`. The fork rev is unchanged.
- **Rejected:**
  - a switch;
  - a smaller split ratio;
  - a separate workspace;
  - focusing the new tab.

## Steps

1. **`pkgs/herdr-claude-teams/teammate-tabs.patch` (new) and
   `default.nix`: `split-window` creates a tab.**
   - Create the patch against the fork as it stands after
     `ownership.patch`:
     1. Unpack the source with `nix build …herdr-claude-teams.src` and
        `cp -r`.
     2. Apply `ownership.patch`.
     3. `git init` and commit as the base.
     4. Edit.
     5. `git diff > teammate-tabs.patch`.
   - `src/herdr_claude_teams/verbs.py`, `_split_window` (installed
     line 206): replace the `pane.split` call and its params with the
     tab create-and-move above. Keep:
     - the trailing-command `send_text`;
     - the `-P`/`-F` print block (lines ~245–249);
     - `ownership.record`.

     Add a small `_place_after_lead(new_tab_id, lead_tab_id, workspace_id)`
     helper.
   - `default.nix` line 21: `patches = [ ./ownership.patch ./teammate-tabs.patch ];`.
     Update the header comment by half a line ("teammates open as tabs
     after the lead").
   - Tests, in the fork's `tests/` (inside the patch):
     - extend the fake-herdr `conftest.py` handlers with `tab.create`,
       `tab.move`, `tab.list` and `pane.get` (with `tab_id`);
     - new tests for: create (focus false, lead's workspace); move to lead
       index + 1, and + 2 for a second split; a failed move still exits 0
       and records ownership; `-P` prints the root pane;
     - update the existing split tests that assert `pane.split`.

   Verify by:
   `nix build .#nixosConfigurations.p620.pkgs.customPkgs.herdr-claude-teams -L`
   (`pytestCheckHook` runs the suite). Report the real exit code.

   Traps:
   - Check `tab.move`'s `insert_index` base against `tab.list` order in a
     fake test, and confirm it live in step 5.
   - `pyproject` packages use `src/` layout: check the real path before
     writing the patch.
   - Use `set -o pipefail`.

2. **Same patch: `resize-pane` no-op and the tab label.**
   - `_resize_pane` (installed line 602): before `pane.resize`, look up the
     target's tab with `pane.get`, then `tab.get` (or `tab.list` for its
     `pane_count`). If `pane_count == 1`, log through `trace` and
     `return 0`. Do the same for the `-x`/`-y` absolute path
     (`_resize_pane_absolute`, line 503).
   - `relabel.py` (`relabel()`, line 18): after sending `split_mark`, also
     `tab.rename {tab_id: <pane's tab>, label}`, but only when the pane is
     owned and alone in its tab. A failure is ignored, as the existing
     relabel does.
   - Tests: a resize on a single-pane tab makes no `pane.resize` call and
     exits 0; a relabel renames the owned tab.

   Verify by: the step 1 build command.

   Traps:
   - Never rename a tab whose root pane is not owned.

3. **`docs/applications/herdr.md`: document Claude agent teams.**
   - Add a short `## Claude agent teams` section. None exists yet; #2616
     never documented it. It covers:
     - `claude` inside herdr runs `herdr-claude-teams`;
     - each teammate opens in its own tab right after the lead's tab,
       labelled `↳ <name>`, without taking focus;
     - the lead stopping a teammate closes its tab;
     - `claude-swarm-reaper` closes teammates idle for 10 minutes;
     - only panes and tabs the shim created are ever closed.

     Commands go in fenced blocks.
   - Bump `Last Updated` if the page has it.

   Verify by: `markdownlint-cli2 docs/applications/herdr.md`.

   Traps:
   - Pre-push lints the whole file.
   - Nav is unchanged (existing page).

4. **Build both hosts.** `just test-host p620` and `just test-host razer`,
   checking exit codes.

5. **Review and PR.**
   - A fresh Opus agent reviews this plan and `git diff origin/main`.
   - Open the PR linking all three artifacts.
   - Deploy after merge.

6. **Deploy p620 and verify live in a real herdr session.**
   - Before the deploy:
     - check that nhs is not running;
     - bus `read_new` and `post`;
     - `AGENT_BUS_ANNOUNCED=1 just p620`;
     - check there are no failed units.
   - Snapshot the pane and tab lists.
   - Create a test tab. Its `cd` goes into a trusted directory (memory: the
     scratchpad cwd stalls on the trust prompt).
   - Type the team prompt into the running `claude`. `send-text` of a long
     shell line cut it short in #2616.
   - Expect:
     - two tabs right after the lead's tab, labelled `↳ alpha` and
       `↳ beta`;
     - the lead's pane keeps its size and focus;
     - after the lead stops them, both tabs close and no empty tab
       remains.
   - Reaper:
     1. First list `claude-swarm-*` sockets and owned records. If another
        session has idle teammates, wait or ask.
     2. Spawn gamma, leave it idle, run
        `claude-swarm-reaper reap --idle-minutes 1` twice about 70 s
        apart.
     3. Gamma's tab closes.
   - Afterwards:
     - the user's panes and tabs are unchanged;
     - the trace log shows no failing verb;
     - close the test tab.

   Traps:
   - A stale Hyprland signature does not matter here (herdr socket only).
   - If `tab.move` misplaces by one, fix the index base in the patch.
     Record it as a deviation.

7. **Deploy razer.**
   - `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`.
   - Check there are no failed units.
   - The live check only if a herdr server runs there.

   Traps:
   - razer exit 4 from syncthing is cosmetic.
   - Never touch p510.

## Tests

```bash
nix build .#nixosConfigurations.p620.pkgs.customPkgs.herdr-claude-teams -L
just test-host p620
just test-host razer
markdownlint-cli2 docs/applications/herdr.md
```

Expected:

- The fork suite, the ownership tests and the new tab, resize and relabel
  tests pass.
- Both hosts build.
- The live checks in step 6 pass.

## Review

A fresh Opus agent gets this plan and `git diff origin/main`.

## Rollback

Revert the PR and redeploy. Without `teammate-tabs.patch`, teammates go
back to splits in the lead's tab. Owned records stay compatible, so no
cleanup is needed.
