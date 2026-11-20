---
status: approved
issue: 3139
intent: intent/2026-11-20-3139-keeploaded-unload.md
---

# Spec: make nixarchy.herdr safe to unload

Scope per the owner's decision: herdr only. pkg, podman, flatsnap and govee
are #3144.

## Design

### What the menu owns today (olafkfreund/nixarchy-herdr `c16db87`, the rev this repo pins)

`Menu.qml` builds its own `HerdrModel { remote: true }` (`Menu.qml:101-110`).
The bar's `Panel.qml` builds its own local one, one per monitor
(`Panel.qml:54-57`). In the menu's model:

| Object | What it runs | On unload |
| --- | --- | --- |
| `appSubProc` | `hc events --json`, started by `Component.onCompleted: appStart()` (`HerdrModel.qml:1482`), plus its watchdog, backoff and retry timers | may die: read-only |
| `appListProc` | `herdr-sessions app-list --remote`, on every hc event | may die: read-only |
| `listProc`, `hostPolls` | `list` and per-host polls; the poll timer runs only while open (`:1497-1505`) | may die: read-only |
| `actionProc` | `new`, `open`, `focus`, `delete`, `app-new`, `app-focus`, `app-interrupt` (`:393-412`, `:1101-1115`) | **must survive** |
| `killProc` | `kill`, and `app-kill` with its cascade key (`:1132-1141`) | **must survive** |
| `promptProc` (`Menu.qml:330-348`) | `prompt` / `app-prompt` | dies on close already: `close()` calls `cancelInput()` on purpose (`:89-94`) |
| `textFile.setText()` (`:1036-1040`) | the shared text-scale file | a synchronous `FileView` write, accepted (see Risks) |

The `hc events` subscription is not only a login cost. It runs, and keeps
triggering `app-list --remote`, for as long as the menu stays loaded. Today
that is the whole session.

### Change in nixarchy-herdr (one PR)

1. **`HerdrActions.qml`, a singleton.** It has `pragma Singleton` and is
   listed in a new `qmldir` as `singleton HerdrActions 1.0 HerdrActions.qml`,
   the same pattern as nixarchy-devenv's `DevenvState`. It owns one
   `action` process and one `kill` process **per registered model**. It
   creates them as child objects when a model registers. Each model has a
   surface: `menu` for the `remote: true` model, or `bar`.

   This keeps today's concurrency exactly. The bar builds one model per
   monitor (`Panel.qml:64-67`), and each keeps its own pair, as it does now.
   A slow menu action never makes a bar click answer `busy:`, and a kill and
   an action can still overlap. Each process body is today's `actionProc`
   or `killProc`, moved unchanged. The slots are QML objects with real
   properties (`running`, `open`, `meta`), so bindings to them update.
2. **Each run carries its own metadata.** `HerdrActions.start(owner, surface,
   kind, command, meta)` returns false while that slot is `running || open`
   (stdout and exit arrive in either order, `HerdrModel.qml:235-256`). The
   caller then shows today's `busy: <action> is still running`. It
   stores, per run and before the process starts:
   - `owner`;
   - `actionName`, `actionDismiss` and `pendingKey` or `killPendingKey`;
   - for `app-kill`, the session and agent refs.

   A refused start changes nothing, so it cannot retarget a run already in
   that slot. `HerdrActions` parses the result once, into
   `{ok, note, error, changed, cascade, cascadeKey, code}`. This is today's
   logic from `complete()`, `HerdrModel.qml:273-293`, moved and not
   duplicated.
3. **Owners register.** Each `HerdrModel` makes a token and registers it in
   `Component.onCompleted`, and unregisters it in `Component.onDestruction`.
   When a run finishes:
   - **The owner is alive** (the bar, or a menu still loaded but hidden).
     `finished(run, result)` goes to that model only. It handles the result
     exactly as `complete()` does now:
     - `actionError` from the error or the note;
     - `dismiss()` and `actionFinished(action, ok)` for actions;
     - the changed-cascade re-confirm for kills;
     - `settleTimer.restart()`.
   - **The owner is gone** (the menu unloaded). Its process pair stays
     alive until the run completes, then is destroyed. The parsed result is
     stored in `unclaimed.menu[kind]`, one slot per kind, so a kill and an
     action that both finish while closed are both kept. A result of a
     destroyed *bar* model (a monitor unplugged) is dropped: no bar
     surface claims. `unclaimed` is replaced, never mutated, so its change
     signal fires.
4. **Only the menu claims, and only when it is shown.** Only a
   `remote: true` model claims, so no bar model takes a menu result. It
   claims in `onOpenedChanged` after the existing `actionError = ""`
   (`:1298-1300`), and again on `unclaimedChanged` while it is open. That
   second path covers a menu reopened before the old run finished.

   Claiming does these things:
   - sets `actionError` from both kinds' results at once. Non-empty
     messages are kept and joined with a semicolon, so a success with no note
     never erases a failure;
   - restarts `settleTimer` and runs `appRunList()`, so both the session
     list and the app list refresh. `Menu.open()` has already started
     `listProc`, so a bare `refresh()` would be a no-op;
   - clears the slot.

   Claiming never calls `dismiss()` or `actionFinished`, and never opens a
   dialog. A claimed changed-cascade kill becomes the error "the agents to
   end changed; press the key again", so a kill always needs a fresh
   confirmation.
5. **Pending rows.** `HerdrModel` keeps the `pendingKey` and
   `killPendingKey` properties that `Card.qml:321-322` binds to. They are
   now read-only bindings to its own slots in `HerdrActions`. A reopened
   menu is a new model with new slots, so it does not dim the row of an
   orphaned run. That run's result arrives through `unclaimed` instead.
6. **`manifest.json`:** drop `"keepLoaded": true` and bump the version to
   1.3.0. Update every comment, README line and test that says the menu
   stays loaded.

In-menu cancellation stays as it is. Closing still cancels a waiting prompt
(`cancelInput()`), and remote host polls still run only while the menu is
open.

### Unload semantics

These are the same as for the #3107 plugins (spec 3107, section 1). A
toggle-close or `shell hide` unloads the menu. Esc or a click-away hides it
once it has been opened. The keybind
(`omarchy-shell shell toggle nixarchy.herdr`) loads it on demand. The bar
widget is a separate entry point with its own model, so the bar badge, its
IPC target (`ipcTarget: "nixarchy.herdr"`, `Panel.qml:47`) and its
click-to-focus are unaffected.

### Change in this repo

`flake.nix:77-80`: move the `nixarchy-herdr` pin to the merge commit of the
PR above (the existing #2983 override pattern) and update its comment.
Nothing else changes here.

## Alternatives rejected

- **Load the model lazily but keep `keepLoaded`.** A `Loader` around the
  menu's model, active from the first open on. It is the smallest diff, but
  the menu is still built at login, and its `hc events` subscription runs
  for the rest of the session once opened. Both go against the approved
  outcome. It is the fallback if the singleton proves unworkable.
- **Shared slots per surface and kind.** This was in the first approved
  draft. Rejected because the bar has one model per monitor, so bar actions
  on different monitors would have answered `busy:` for each other, which
  is a behaviour change.
- **Run actions with `Quickshell.execDetached`.** This loses the JSON
  result that `new`'s pending line, the cascade re-check and `actionError`
  depend on.
- **Hand actions to `systemd-run --user` units.** Results would have to
  come back through a file. That is more moving parts than a singleton.
- **Share the bar's model with the menu.** `Menu.qml:17-19` keeps them
  apart on purpose, because the menu must work on a machine whose bar does
  not carry the widget.

## Risks

- **Singleton lifetime.** A `pragma Singleton` object belongs to the
  engine, not to the menu's tree, and devenv's `DevenvState` relies on
  this. The local unload test below proves it for this plugin, with no bar
  model alive.
- **The qmldir changes type lookup.** With a `qmldir` present, the
  directory import goes through it. In devenv, unlisted `.qml` files still
  resolve. `qml-load.sh` (local) catches a miss.
- **Result routing.** A token or surface mix-up could show one surface's
  result in the other. The two-model test covers it.
- **Text-scale write.** `FileView.setText()` on a key press, then an
  immediate toggle-close. The write is issued before the close is handled,
  and the risk is a lost size preference at worst. It is accepted, and a
  live check is listed below.
- **Hosts:** p620 and razer. p510 is not touched without the owner's OK.

## Verification

**CI (nixarchy-herdr `ci.yml`):** the node tests (`tests/*.cjs`), the bash
syntax checks, shellcheck and `tests/herdr-sessions.sh` still pass. The QML
tests need `qs` and an installed omarchy-shell, so they run locally (on
p620), as today.

**Local QML tests:**

- `tests/qml-load.sh` still passes. `HerdrActions.qml` is compiled through
  `HerdrModel.qml`'s import, not with `Qt.createComponent`, and the expected
  error count is unchanged.
- `tests/app-subscription.sh` is updated to stage `qmldir` and
  `HerdrActions.qml`, and still passes.
- A new `tests/unload.qml` + `.sh` uses a stub `herdr-sessions` placed at
  the model's resolved `bin/` path. The stub signals that it started,
  sleeps, then writes a marker and its JSON. No bar model is alive. Cases:
  1. Start `focus`, wait for the started signal, deactivate the `Loader`.
     The marker appears, and `unclaimed.menu.action` holds the parsed
     result.
  2. Build a new menu model and open it. Its `actionError` shows the stored
     error after `onOpenedChanged`.
  3. Reopen before completion: the open menu claims the result through
     `unclaimedChanged`.
  4. A kill and an action both finish while unloaded. Both are kept and
     claimed.
  5. A kill returns `changed: true` while unloaded. It becomes the "press
     the key again" error, and no dialog opens.
  6. A start that fails to launch while unloaded is kept as an error.
  7. A bar model and a menu model, with an action running in each: each
     result reaches its own model, and a second start in the same slot
     answers `busy:`.

**On p620, after the pin moves and a switch:**

- `jq .keepLoaded` on the installed manifest is null.
- After a fresh login, `pgrep -af 'hc events --json'` shows one process
  (the bar's), not two. Opening the menu makes it two, and a toggle-close
  makes it one again within a few seconds. The plan step also looks for a
  shell-side way to list the loaded plugin views. If one exists, it proves
  the menu is not built before the first open. If not, the process count
  stands in for it.
- In-flight check: start `n` (a new session) from the menu and toggle-close
  at once. The session exists afterwards (`herdr-sessions list`), and on
  reopen the menu shows it with no error.
- The bar badge, IPC and click-to-focus work before the first menu open,
  and after an unload.
- After `Ctrl+=` and an immediate toggle-close, the text-scale file holds
  the new size.
