---
status: draft
issue: 3139
intent: intent/2026-11-20-3139-keeploaded-unload.md
---

# Spec: make nixarchy.herdr safe to unload

Scope per the owner's decision: herdr only. pkg, podman, flatsnap and govee
are #3144.

## Design

### What the menu owns today (olafkfreund/nixarchy-herdr `c16db87`, the rev this repo pins)

`Menu.qml` builds its own `HerdrModel { remote: true }` (`Menu.qml:101-110`).
The bar's `Panel.qml` builds a second, local one. In the menu's model:

| Object | What it runs | On unload |
| --- | --- | --- |
| `appSubProc` | `hc events --json`, started by `Component.onCompleted: appStart()` (`HerdrModel.qml:1482`), plus watchdog, backoff and retry timers | may die: read-only |
| `appListProc` | `herdr-sessions app-list --remote`, on every hc event | may die: read-only |
| `listProc`, `hostPolls` | `list` and per-host polls; the poll timer runs only while open (`:1497-1505`) | may die: read-only |
| `actionProc` | `new`, `open`, `focus`, `delete`, `app-new`, `app-focus`, `app-interrupt` (`:393-412`, `:1101-1115`) | **must survive** |
| `killProc` | `kill`, `app-kill` with its cascade key (`:1132-1141`) | **must survive** |
| `promptProc` (in `Menu.qml:330-348`) | `prompt` / `app-prompt` | dies on close already: `close()` calls `cancelInput()` on purpose (`:89-94`) |

The `hc events` subscription is not only a login cost. It runs, and keeps
triggering `app-list --remote`, for as long as the menu stays loaded, which
today is the whole session.

### Change in nixarchy-herdr (one PR)

1. **`HerdrActions.qml`, a singleton** (`pragma Singleton`, listed in a new
   `qmldir` as `singleton HerdrActions 1.0 HerdrActions.qml`, the same
   pattern as nixarchy-devenv's `DevenvState`). It owns `actionProc` and
   `killProc`, moved unchanged from `HerdrModel.qml`, together with the state
   a run needs to complete:
   - its `open`/`gotOut`/`gotExit` bookkeeping;
   - `actionName`, `actionDismiss`, `pendingKey` and `killPendingKey`;
   - the kill's session and agent refs.

   Each run records the `owner` that started it: a token each `HerdrModel`
   makes on construction.
2. **`HerdrModel` delegates to the singleton.** `launch()` and `appLaunch()`
   call `HerdrActions.start(owner, kind, command, …)`. `complete()` keeps its
   handling for action and kill results, and now receives them through a
   `Connections { target: HerdrActions }` on a `finished(owner, kind, out,
   code)` signal. A model acts only on its own token.
3. **A result whose owner is gone is kept, not lost.** When a run finishes
   after its menu has unloaded, `HerdrActions` stores
   `{kind, action, ok, error}` as `unclaimed`. A model being built takes
   `unclaimed` into `actionError` and refreshes, so on reopen you see
   "focus failed: …" or the session that `new` created. A kill whose cascade
   changed (`data.changed === true`) cannot ask again without its dialog. It
   is stored as an error: "the agents to end changed; press the key again".
4. **Busy is per plugin, not per surface.** Today the bar and the menu can
   each run one action at once. With one `actionProc` and one `killProc` in
   the singleton, a second action from either surface gets the existing
   `busy: <action> is still running`. This is the one behaviour change. It
   is stated in the PR, and it is the same rule devenv uses ("one mutation
   at a time across both surfaces").
5. **`manifest.json`:** drop `"keepLoaded": true`, bump the version to
   1.3.0, and update any comment, README line or test that says the menu
   stays loaded.

The two pieces of in-menu cancellation stay as they are. Closing still
cancels a waiting prompt (`cancelInput()`), and remote host polls still run
only while the menu is open.

### Unload semantics

These are the same as for the #3107 plugins (spec 3107, section 1). A
toggle-close or `shell hide` unloads the menu. Esc or a click-away hides it
once it has been opened. The keybind
(`omarchy-shell shell toggle nixarchy.herdr`) loads it on demand. The bar
widget is a separate entry point with its own model, so the bar badge, its
`IpcHandler` (`Panel.qml:484`) and its click-to-focus are unaffected.

### Change in this repo

`flake.nix:77-80`: move the `nixarchy-herdr` pin to the merge commit of the
PR above (the existing #2983 override pattern) and update its comment.
Nothing else changes here.

## Alternatives rejected

- **Load the model lazily but keep `keepLoaded`.** Wrap the menu's
  `HerdrModel` in a `Loader` that turns active on first open and stays. This
  is the smallest diff: no `hc events` at login and no in-flight risk. But
  the menu is still built at login, and once opened, the subscription runs
  for the rest of the session, against the approved outcome. It is the
  fallback if the singleton turns out to be unworkable in Quickshell.
- **Run actions with `Quickshell.execDetached`.** This loses the JSON
  result that `new`'s pending line, the kill cascade re-check and
  `actionError` depend on.
- **Hand actions to `systemd-run --user` units.** Survives anything, but
  results would have to come back through a file or a unit status. That is
  more moving parts than a singleton, for a menu that has to keep working
  without systemd tricks.
- **Share the bar's model with the menu.** `Menu.qml:17-19` keeps them
  apart on purpose, because the menu must work on a machine whose bar does
  not carry the widget.

## Risks

- **Singleton lifetime.** If Quickshell rebuilt singletons per entry-point
  tree, the action would still die. devenv's `DevenvState` relies on the
  same lifetime, which #3107 checked. The PR test below proves it for this
  plugin.
- **The qmldir changes type lookup.** With a `qmldir` present, the
  directory import goes through it. devenv shows that unlisted `.qml` files
  in the same directory still resolve. `tests/qml-load.sh` catches a miss.
- **Result routing.** A token mix-up could show the bar's error in the menu,
  or the reverse. Covered by a test with two models.
- **Re-entry while a run finishes.** A menu reopened mid-run gets a new
  token and does not adopt the old run. Its result lands in `unclaimed`,
  and the next model built, or the open menu through `Connections` on an
  `unclaimedChanged` signal, picks it up.
- **Hosts:** p620 and razer. p510 is not touched without the owner's OK.

## Verification

In nixarchy-herdr (CI, `tests/`):

- `tests/qml-load.sh` loads `Menu.qml`, `Panel.qml` and `HerdrActions.qml`
  offscreen with no errors.
- A new `tests/unload.qml` + `.sh`, in the style of `app-subscription.*`:
  - A stub `herdr-sessions` sleeps 2 s and then writes a marker. A
    `HerdrModel` inside a `Loader` starts `focus`, and the `Loader` is
    deactivated at once. The marker appears, and `HerdrActions.unclaimed`
    holds the result.
  - Two models: the result reaches the model that started the run, never
    the other.
  - A second action while one runs gets `busy:`.
- `node` tests (`tests/*.cjs`) still pass.

On p620 after the pin moves and a switch:

- `jq .keepLoaded` on the installed manifest is null.
- After a fresh login, `pgrep -af 'hc events --json'` shows one process
  (the bar's), not two. Opening the menu makes it two. A toggle-close makes
  it one again within a few seconds.
- In-flight check: start `n` (a new session) from the menu and toggle-close
  at once. The session exists afterwards (`herdr-sessions list`), and on
  reopen the menu shows it with no error.
- The bar badge updates and click-to-focus works before the first menu
  open and after an unload.
