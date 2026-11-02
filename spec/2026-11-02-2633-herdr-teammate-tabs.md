---
status: approved
issue: 2633
intent: intent/2026-11-02-2633-herdr-teammate-tabs.md
---

# Spec: Claude teammates open in a new herdr tab

## Decisions on the intent's open questions

The user said "use your recommendations".

- **Sidebar order:** each teammate tab is placed right after the lead's tab,
  in spawn order, so the `↳ <name>` rows sit directly under the lead in the
  sidebar (`agent_panel_sort = "spaces"` lists tabs in order).
- **Tabs only:** tabs are the only behaviour. There is no switch. A split
  mode nobody uses would be dead code, and reverting the patch brings
  splits back.

## Design

All changes go in the herdr-claude-teams package as a second local patch,
`pkgs/herdr-claude-teams/teammate-tabs.patch`, listed after
`ownership.patch` in `patches`. The pinned fork rev is unchanged.

### 1. `split-window` creates a tab (`verbs.py`, the split handler)

Today `split-window` calls `pane.split`. It will instead:

- **Find the lead's tab:** resolve the target pane (`-t`, else
  `TMUX_PANE`, which is the lead) with `pane.get`. That gives its
  `tab_id` and `workspace_id`.
- **Create the tab:** call `tab.create` with
  `{workspace_id, cwd: -c if given, focus: false}`. Focus is never taken:
  Claude Code tracks teammate pane ids itself, and the lead must keep the
  user's focus. The jcode "focus follows split" case gets no exception,
  because there is no jcode on these hosts.
- **Place it:** call `tab.move` with
  `{tab_id: new, insert_index: <lead tab's index> + 1 + <owned teammate tabs already after it>}`.
  This puts teammates after the lead in spawn order. The index comes from
  `tab.list` for the workspace, as the position of the lead's tab plus the
  owned tabs that directly follow it.
  - If the move fails, the tab stays where herdr put it (at the end). It
    is logged and not fatal.
- **Record ownership:** call `ownership.record(root_pane)` for the new
  tab's root pane, exactly as `new-window` does today. The three-field
  `.owned` line (socket, pane_id, terminal_id) is unchanged, so `kill-pane`,
  `respawn-pane`, the relabel and the reaper all keep working.
- **Run the command and print the pane:** if there is a trailing command,
  deliver it with `pane.send_text`, as today. With `-P`, print the root
  pane id in tmux form, as today.

### 2. Layout calls that no longer apply

- **Which calls:** Claude Code follows a split with layout calls such as
  `resize-pane` on the lead or teammate panes. With one pane per tab,
  herdr has nothing to resize.
- **Change:** `resize-pane` against a pane that is alone in its tab
  becomes a logged no-op with exit 0, like `select-layout` today.
- **Why:** a non-zero exit there could make Claude treat the spawn as
  failed.

### 3. Closing

- **Shutdown and reaper:** closing a teammate goes through the existing
  `kill-pane` (from Claude at shutdown) and the reaper's `pane.close`.
  When the closed pane is the tab's only pane, herdr closes the tab.
- **Verification:** this is checked live. If herdr leaves an empty tab,
  the patch calls `tab.close` on the owned root pane's tab instead, after
  the same `terminal_id` check. `pkgs/claude-swarm-reaper` then makes the
  same change.

### 4. Tab label

- **Label:** the teammate tab gets the label `↳ <name>`, set wherever the
  relabel already sends the `split_mark` (`relabel.py`, `tab.rename` on
  the owned root pane's tab).
- **Before the name is known:** the tab shows herdr's default label until
  the name arrives.

### 5. Tests

Fake-herdr tests in the fork's suite, using the existing `conftest.py`
handlers plus `tab.create`, `tab.move` and `tab.list` handlers:

- `split-window` issues `tab.create` (focus false, lead's workspace) and
  `tab.move` to the lead's index + 1. A second split lands at + 2.
- A failed `tab.move` still returns 0 and records ownership.
- `-P` prints the new root pane. The `.owned` record has its
  `terminal_id`.
- `resize-pane` on a single-pane tab exits 0 without calling
  `pane.resize`.

The fork's existing split tests are updated to expect the tab calls. These
are the tests that assert `pane.split`.

### 6. Docs

The herdr page that documents #2616 now says teammates open as tabs after
the lead's tab, and drops the "splits of the lead's tab" wording. Find it
with `grep -rl herdr-claude-teams docs/`.

## Alternatives rejected

- **A split/tab switch:** see the decisions above.
- **Leave splits and set a small split ratio:** the managing pane still
  shrinks with each teammate, and several teammates become unreadable.
- **Teammates in a separate workspace:** the lead's workspace would no
  longer show its own team, and moving between workspaces is heavier than
  moving between tabs.
- **Focus the new tab, like tmux new-window:** it steals the user's
  attention from the lead on every spawn.

## Risks

- **Index semantics (p620 and razer):** `tab.move`'s `insert_index` may be
  0-based where `tab.get` reports a 1-based `number`. An off-by-one only
  misplaces the tab. The order is checked live and fixed in the patch.
- **An empty tab left behind (both hosts):** covered by §3 and the live
  check.
- **Claude Code's tmux backend may call more pane verbs** than today's
  shim handles, for teammate panes that are no longer siblings of the
  lead. The trace log (`trace.py`) is read after the live test, and any
  failing verb is handled in the patch.
- **The user's own tabs:** a `tab.move` targets only the newly created,
  owned tab, and indices are computed from a fresh `tab.list`. Before and
  after pane and tab lists are compared in the live test, as in #2616.

## Verification

1. `nix build .#nixosConfigurations.p620.pkgs.customPkgs.herdr-claude-teams -L`:
   the fork's suite, the ownership tests and the new tab tests pass.
2. `just test-host p620` and `just test-host razer` build.
3. Live on p620, after deploy, in a real herdr session (the #2616 recipe):
   - **Spawn:** the lead spawns alpha and beta. Two new tabs appear
     directly after the lead's tab, labelled `↳ alpha` and `↳ beta`. The
     lead's pane keeps its size and focus.
   - **Close:** the lead stops both, and both tabs close with no empty tab
     left.
   - **Reaper:** an idle teammate gamma is closed by
     `claude-swarm-reaper reap --idle-minutes 1` (two passes), and its tab
     goes away.
   - **Other sessions:** this run is done when no other session has an
     idle swarm teammate, or by checking `claude-swarm-*` sockets first.
     #2616's test reaped another session's teammate.
   - **User's panes:** the user's panes and tabs are unchanged before and
     after.
   - **Trace:** the trace log shows no failing verb.
4. razer: the same build and deploy. The live check is skipped if no herdr
   server runs there, as in #2616.
