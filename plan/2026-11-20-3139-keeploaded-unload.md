---
status: draft
issue: 3139
spec: spec/2026-11-20-3139-keeploaded-unload.md
coders:
  1: codex  # small, tricky logic: the singleton and HerdrModel's rewiring, verified together
  2: coder  # test harness work in the style of the existing QML tests
  3: coder  # manifest and wording, a few lines
reviewers:
  - codex   # a fresh Codex review session, given only the diff and this plan
  - agy     # independent read of the diff against this plan
---

# Plan: make nixarchy.herdr safe to unload

## Approved decisions (from the spec)

- **Scope:** only herdr. pkg, podman, flatsnap and govee are #3144.
- **`HerdrActions.qml` singleton:**
  - `pragma Singleton`, listed in a new `qmldir` that holds only
    `singleton HerdrActions 1.0 HerdrActions.qml`: no `module` line and no
    other files (the nixarchy-devenv `DevenvState` pattern).
  - **Process slots are per model.** It owns one `action` slot and one
    `kill` slot per registered `HerdrModel`, created as child objects on
    `register()`.
  - The surface is `menu` for the `remote: true` model, `bar` otherwise.
    The bar has one model per monitor (`Panel.qml:64-67`), and each keeps
    its own pair, so today's concurrency is unchanged.
  - A slot is a QML object with real properties (`running`, `open`, `meta`,
    plus today's `out`/`code`/`gotOut`/`gotExit`), so bindings to it
    update.
- **Starting a run:** `start(owner, kind, command, meta)` returns false
  while the slot is `running || open`. The caller then sets today's
  `busy: <kill | the running meta's actionName> is still running`.
  - Before the process starts, `start()` stores the run's `meta`:
    `actionName`, `actionDismiss`, `pendingKey` or `killPendingKey`, and,
    for `app-kill`, the session and agent refs.
  - A refused start changes nothing.
- **Parsing a result:** done once in `HerdrActions`, into
  `{ok, note, error, changed, cascade, cascadeKey, code}`. This is today's
  logic from `HerdrModel.qml:273-293`. Completion fires once, whichever of
  stdout and exit arrives last (today's `storeResult`, `startFailed`,
  `finishRun`).
- **Owners:** a model registers its token in `Component.onCompleted` and
  unregisters it in `Component.onDestruction`. When a run finishes:
  - **Owner alive:** `finished(owner, kind, meta, result)` is handled by
    that model only, exactly as `complete()` handles it now: `actionError`,
    `dismiss()`, `actionFinished`, the changed-cascade re-confirm,
    `settleTimer.restart()`.
  - **Owner gone:** its slot pair lives until the run completes, then is
    destroyed.
    - A menu result goes to `unclaimed.menu[kind]`, one per kind.
    - A bar result (a monitor unplugged) is dropped.
    - `unclaimed` is replaced, never mutated, so `unclaimedChanged` fires.
- **Claiming:** only a `remote: true` model claims.
  - When: in `onOpenedChanged` after `actionError = ""` (`:1298-1300`), and
    on `unclaimedChanged` while it is open.
  - What it does:
    - takes both kinds at once and sets `actionError` from them, keeping
      each non-empty message and joining them with a semicolon;
    - runs `settleTimer.restart()` and `appRunList()`;
    - clears what it took.
  - It never dismisses, never emits `actionFinished` and never opens a
    dialog. A changed-cascade kill becomes the error
    `the agents to end changed; press the key again`.
- **Pending rows:** `pendingKey` and `killPendingKey` stay as `HerdrModel`
  properties (`Card.qml:321-322` binds them). They become read-only
  bindings to the model's own slots' `meta`.
- **Manifest:** drop `"keepLoaded": true`, and set the version to 1.3.0.
- **Unchanged:** `promptProc` is still cancelled by `close()`, and remote
  polls still run only while the menu is open.
- **This repo:** move the `nixarchy-herdr` pin in `flake.nix:77-80` to the
  PR's merge commit.

## Where the work happens

- **Plugin:** a clone of olafkfreund/nixarchy-herdr at
  `/home/olafkfreund/.config/nixarchy-herdr-3139`, branch
  `perf/3139-unload`, from `main` (`c16db87`, the rev this repo pins).
  Steps 1-3 edit only that clone.
- **Pin bump:** steps 5-6 run in the worktree
  `/home/olafkfreund/.config/nixos-3139`, branch
  `perf/3139-keeploaded-unload`.

## Steps

1. **`HerdrActions.qml`, `qmldir`, and `HerdrModel.qml` rewired.** This is
   one step, because neither file can be checked without the other.
   - **New `HerdrActions.qml`.**
     - It holds a slot `Component` with one copy of today's `Process`
       block (`HerdrModel.qml:1400-1413`), plus the `meta`/`open`
       bookkeeping.
     - `register(token)` creates the model's `action` and `kill` slots, and
       `unregister(token)` marks them orphaned.
     - `start(owner, kind, command, meta)` returns a bool, and
       `slot(owner, kind)` returns the slot object.
     - `unclaimed`, `claimMenu()` (takes and clears both kinds), and the
       signals `finished(owner, kind, meta, result)` and
       `unclaimedChanged()`.
   - **New `qmldir`:** a single line,
     `singleton HerdrActions 1.0 HerdrActions.qml`.
   - **`HerdrModel.qml`:**
     - Remove `actionProc` and `killProc` (`:1400-1428`).
     - Remove the writable `actionName` (`:115`), `actionDismiss` (`:116`),
       `killPendingKey` (`:118`), `pendingKey` (`:127`) and
       `killSessionRef`/`killAgentRef` (`:136-137`). Replace them with
       read-only bindings to `HerdrActions.slot(token, …).meta`.
     - `launch()` (`:393-412`) and `appLaunch()` (`:1101-1115`) build
       `meta` and call `start()`. On false, they set the `busy:` text.
     - `appKill()` (`:1132-1141`) passes `{session, agent}` in `meta` and no
       longer assigns the refs after the launch.
     - `complete()` keeps the `list`, `applist` and `host` kinds. A new
       `onResult(kind, meta, result)` does today's action and kill
       handling.
     - Add the token, `register` in `Component.onCompleted` (beside
       `appStart()`, `:1482`) and `unregister` in `Component.onDestruction`.
     - Add `Connections { target: HerdrActions }`. It filters `finished` on
       the model's own token, and when `remote && opened` it claims on
       `unclaimedChanged`.
     - In `onOpenedChanged`, claim after `actionError = ""` when `remote`.
   - **`tests/session-actions.cjs`:** this is a harness refactor, not a
     rename. It extracts `launch`, `appLaunch`, `complete`, `storeResult`,
     `startFailed`, `finishRun` and `appKill` and runs them in `node:vm`
     against stubbed `actionProc`/`killProc` (`:7-38`, `:53-60`,
     `:202-325`, `:618-666`). Extract the moved functions from
     `HerdrActions.qml` and stub the singleton. Keep every existing
     assertion:
     - argument order;
     - stdout/exit in either order completing once;
     - `busy:` while only `open` is true;
     - cascade re-confirm.

     Add one assertion: a refused start leaves the running slot's `meta`
     untouched.

   Verify:
   - `for f in tests/*.cjs; do node "$f" || exit 1; done` passes.
   - `bash tests/qml-load.sh` passes with its expected count. Do not add
     `HerdrActions.qml` to its `createComponent` list: a singleton is not
     creatable, and it compiles through `HerdrModel.qml`.

   Traps:
   - A QML binding to a function that returns a plain JS object never
     updates, so slots must be QML objects.
   - The two orphaned slots must not be destroyed while `running || open`.
2. **QML test harnesses.**
   - `tests/app-subscription.sh:9` and `tests/text-scale.sh:9` also copy
     `qmldir` and `HerdrActions.qml` into `$tmp/shell/`.
   - Add `tests/unload.qml` and `tests/unload.sh` in the same style, with
     these pieces:
     - a stub `herdr-sessions` at the model's resolved `bin/` path, and
       stubbed `Commons`;
     - a cleanup trap on `sleep 33.$$` (the others use 31 and 32);
     - a separate temp directory per case.
   - The stub writes a started-file, sleeps, then writes a marker and its
     JSON. Unless a case says otherwise, no bar model is alive. Cases:
     1. A focus run, unloaded after the started-file appears: the marker
        appears, and `unclaimed.menu.action` holds the parsed result.
     2. A new `remote: true` model is opened: its `actionError` shows the
        stored error after `onOpenedChanged`.
     3. A menu reopened before completion claims the result through
        `unclaimedChanged`.
     4. A failing kill and a succeeding action with no note both finish
        while unloaded: on open, `actionError` still shows the kill's
        error.
     5. A kill with `changed: true` while unloaded: the "press the key
        again" error, and no dialog (`confirmOpen` stays false).
     6. A failed launch while unloaded is kept as an error.
     7. Two bar models and one menu model, each with an action running:
        each result reaches its own model, a second start in one slot
        answers `busy:`, and the bar models never claim.

   Verify: `bash tests/app-subscription.sh`, `bash tests/text-scale.sh` and
   `bash tests/unload.sh` all pass locally on p620.

   Traps: none beyond the ones listed in the step.
3. **Manifest and wording.**
   - `manifest.json:25`: delete the `keepLoaded` line and the trailing
     comma on line 24. Set `version` (line 5) to 1.3.0.
   - Grep `*.qml`, `README.md` and `tests/` for text saying the menu stays
     loaded, and fix it.

   Verify: `jq -e 'has("keepLoaded")|not' manifest.json` succeeds, and
   `jq -r .version manifest.json` prints 1.3.0.

   Traps: none.
4. **Plugin PR (lead).**
   - Run all of steps 1-3's checks, plus CI's own commands verbatim
     (`ci.yml:10-17`):
     - `for f in bin/herdr-sessions bin/herdr-menu-keys tests/herdr-sessions.sh; do bash -n "$f"; done`;
     - `shellcheck bin/herdr-sessions bin/herdr-menu-keys tests/herdr-sessions.sh`;
     - the node loop;
     - `bash tests/herdr-sessions.sh`.

     Also run `shellcheck` on `tests/app-subscription.sh`,
     `tests/text-scale.sh` and `tests/unload.sh`.
   - Commit, push, and open a PR on olafkfreund/nixarchy-herdr. It links
     this plan and states the text-scale risk. The behaviour is otherwise
     unchanged.
   - Reviews:
     - an Opus agent given only this plan and the diff;
     - a fresh Codex session and agy, through `second-opinion`.

     Fix the findings, then merge once CI passes.

   Verify: `gh pr view <n> --json mergeCommit` gives the merge SHA. Record
   it here for step 5.
5. **Pin bump (lead).**
   - `flake.nix:77-80`: set `inputs.nixarchy-herdr.url` to the SHA from
     step 4. Change the comment to cite #3139 and the new rev, keeping the
     comment from starting with `#3139`.
   - Run `nix flake update nixarchy-herdr`.

   Verify:
   - `jq -r '.nodes["nixarchy-herdr"].locked.rev' flake.lock` shows that
     SHA.
   - `just test-host p620` and `just test-host razer` build.

   Traps: never commit in `~/.config/nixos`.
6. **PR, deploy and live checks (lead).**
   - Open the PR from `perf/3139-keeploaded-unload`, linking intent, spec
     and plan, and merge after CI passes.
   - Fast-forward `~/.config/nixos`. Read the bus, post, then run
     `AGENT_BUS_ANNOUNCED=1 just quick-deploy p620`. The owner then logs out
     and back in.
   - Live checks on p620, where **B** is the number of bar widgets:
     - `jq .keepLoaded` on the installed manifest is null.
     - After login, `pgrep -c -f 'hc events --json'` is B. Opening the menu
       makes it B+1. It returns to B within a few seconds after a
       toggle-close, and again after a `shell hide`. Esc and a click-away
       hide the menu without unloading it, so the count stays B+1.
     - In-flight check: start `n` (a new session) and toggle-close at once.
       `herdr-sessions list` shows the session, and on reopen the menu
       shows it with no error.
     - The bar badge, IPC and click-to-focus work before the first open
       and after an unload.
     - After `Ctrl+=` and a quick toggle-close, the text-scale file holds
       the new size.
     - Look for a shell-side way to list the loaded plugin views, and use
       it if it exists.
   - Post the results as a comment on #3139.
   - razer: a new bus post, then `AGENT_BUS_ANNOUNCED=1 just
     deploy-via-p620 razer`. p510: only with the owner's OK.

   Verify: every check passes, and the comment is posted.

## Tests

| Where | Command | Expected |
|---|---|---|
| plugin, CI | `ci.yml:10-17` commands verbatim | all pass |
| plugin, local | `bash tests/qml-load.sh` | passes, same allowed-error count |
| plugin, local | `bash tests/app-subscription.sh`, `bash tests/text-scale.sh` | pass |
| plugin, local | `bash tests/unload.sh` | all 7 cases pass |
| this repo | `just test-host p620`, `just test-host razer` | build |
| p620 live | the step 6 checks | all hold |

## Rollback

- **This repo:** revert the step 5 commit in a worktree. That restores
  both `flake.nix` and `flake.lock` to `c16db87`. Open a PR and merge it,
  then fast-forward `~/.config/nixos`.
- **Hosts:** with a bus post before each host, run
  `AGENT_BUS_ANNOUNCED=1 just quick-deploy p620` and
  `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`. The old model and
  `keepLoaded` return at the next login. p510 is never deployed by this
  task.
- **Plugin:** revert the merge commit on nixarchy-herdr `main`. Nothing
  else depends on `HerdrActions`.
- **Singleton unworkable** (step 2 case 1 fails): stop and record it here.
  Then propose the spec's fallback (a lazy `Loader`, keeping `keepLoaded`)
  to the owner for re-approval. Do not switch to it unasked.
