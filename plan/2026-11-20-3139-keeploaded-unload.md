---
status: draft
issue: 3139
spec: spec/2026-11-20-3139-keeploaded-unload.md
coders:
  1: codex  # small, tricky logic: slot bookkeeping, owner registry, result parsing moved from complete()
  2: codex  # small, tricky logic: rewiring HerdrModel to the singleton without breaking complete()'s paths
  3: coder  # test harness in the style of the existing app-subscription test
  4: coder  # manifest and wording, a few lines
reviewers:
  - codex   # second read of the QML lifecycle logic
  - agy     # independent read of the diff against this plan
---

# Plan: make nixarchy.herdr safe to unload

## Approved decisions (from the spec)

- **Scope:** only herdr. pkg, podman, flatsnap and govee are #3144.
- **`HerdrActions.qml` singleton:**
  - `pragma Singleton`, listed in a new `qmldir` as
    `singleton HerdrActions 1.0 HerdrActions.qml` (the nixarchy-devenv
    `DevenvState` pattern).
  - Four process slots, one per surface (`menu` = the `remote: true` model,
    `bar`) × kind (`action`, `kill`). Today's concurrency is unchanged.
  - The process bodies are today's `actionProc` and `killProc`, moved
    unchanged.
- **Starting a run:** `start(owner, surface, kind, command, meta)`.
  - It refuses with `busy: <action> is still running` when the slot is
    running.
  - Before the process starts it stores the run's metadata: `owner`,
    `actionName`, `actionDismiss`, `pendingKey` or `killPendingKey`, and the
    kill session and agent refs.
  - A refused start changes nothing.
- **Parsing a result:** done once in `HerdrActions`, into
  `{ok, note, error, changed, cascade, cascadeKey, code}`. This is today's
  logic from `HerdrModel.qml:273-293`, moved and not duplicated.
- **Owners:** each `HerdrModel` makes a token, registers it in
  `Component.onCompleted` and unregisters it in `Component.onDestruction`.
  When a run finishes:
  - **Owner alive:** `finished(run, result)` is handled by that model only,
    exactly as `complete()` handles it now: `actionError`, `dismiss()`,
    `actionFinished`, the changed-cascade re-confirm, `settleTimer.restart()`.
  - **Owner gone:** the result goes to `unclaimed[surface][kind]`.
- **Claiming:** a model claims only its own surface's slots.
  - When: in `onOpenedChanged` after `actionError = ""` (`:1298-1300`), and
    on `unclaimedChanged` while it is open.
  - What it does: sets `actionError` (the error, or the note on success),
    runs `settleTimer.restart()` and `appRunList()`, and clears the slot.
  - It never dismisses, never emits `actionFinished` and never opens a
    dialog. A changed-cascade kill becomes the error
    `the agents to end changed; press the key again`.
- **Pending rows:** `pendingKey` and `killPendingKey` stay as `HerdrModel`
  properties. They become read-only bindings to the model's own surface's
  slots (`Card.qml:321-322` binds them).
- **Manifest:** `manifest.json` loses `"keepLoaded": true`, and the version
  goes to 1.3.0.
- **Unchanged:** `promptProc` is still cancelled by `close()`, and remote
  polls still run only while the menu is open.
- **This repo:** move the `nixarchy-herdr` pin in `flake.nix:77-80` to the
  PR's merge commit.

## Where the work happens

- **Plugin:** a clone of olafkfreund/nixarchy-herdr at
  `/home/olafkfreund/.config/nixarchy-herdr-3139`, branch
  `perf/3139-unload`, from `main` (`c16db87`, the rev this repo pins).
  Steps 1-4 edit only that clone.
- **Pin bump:** steps 6-7 run in the worktree
  `/home/olafkfreund/.config/nixos-3139`, branch
  `perf/3139-keeploaded-unload`.

## Steps

1. **`HerdrActions.qml` and `qmldir` (new).** Create the singleton
   described above.
   - Copy the two `Process` blocks from `HerdrModel.qml:1400-1428` four
     times, one per slot. Keep `storeResult`, `startFailed` and
     `finishRun`'s order-independent stdout/exit handling: a failed start
     is reported only by `running` going false.
   - API:
     - `register(token)`, `unregister(token)`;
     - `start(owner, surface, kind, command, meta)`, which returns a bool;
     - `slot(surface, kind)`, giving `running`, `pendingKey` and `meta`;
     - `unclaimed` (an object), `claim(surface, kind)` (returns and clears
       one result), signal `finished(owner, surface, kind, meta, result)`,
       signal `unclaimedChanged()`.

   Verify: `qs` compiles it locally through step 2's import.

   Traps:
   - A singleton file cannot be created with `Qt.createComponent`.
   - The `qmldir` must not list the other `.qml` files; devenv's lists
     only its singleton.
2. **`HerdrModel.qml` delegates.**
   - Remove `actionProc` and `killProc` (`:1400-1428`).
   - `launch()` (`:393-412`) and `appLaunch()` (`:1101-1115`) call
     `HerdrActions.start(...)` with `surface = remote ? "menu" : "bar"`.
     The `busy:` message text stays the same.
   - Move the `ok`/`error`/`note`/`changed` parsing from `complete()`
     (`:273-293`) into `HerdrActions`. `complete()` keeps the `list`,
     `applist` and `host` kinds. A new `onResult(meta, result)` does the
     action and kill handling for a live owner, with today's behaviour.
   - Add the token, `register` in `Component.onCompleted` (next to
     `appStart()`, `:1482`) and `unregister` in `Component.onDestruction`.
   - Add `Connections { target: HerdrActions }` that filters on the
     model's own token for `finished`, and claims on `unclaimedChanged`
     while `opened`.
   - Claim in `onOpenedChanged` after `actionError = ""`.
   - `actionName`, `pendingKey`, `killPendingKey`, `killSessionRef` and
     `killAgentRef` (`:113-137`) become read-only bindings to, or reads
     from, the slot's `meta`.

   Verify: `bash tests/qml-load.sh` passes with the same expected count,
   and `for f in tests/*.cjs; do node "$f"; done` passes.

   Traps:
   - `ui-model.cjs` and `session-actions.cjs` may read these properties or
     process ids from the source text. Grep `tests/*.cjs` for `actionProc`,
     `killProc`, `pendingKey` and `actionName`, and update them in this
     step.
3. **Tests.**
   - `tests/app-subscription.sh:9`: also copy `qmldir` and
     `HerdrActions.qml` into `$tmp/shell/`.
   - Add `tests/unload.qml` and `tests/unload.sh` in the same style: a stub
     `herdr-sessions` at the model's resolved `bin/` path, and stubbed
     `Commons`.
   - The stub writes a started-file, sleeps, then writes a marker and its
     JSON. Run seven cases, with no bar model alive unless the case says
     otherwise:
     1. A focus run unloaded mid-run: the marker appears, and
        `unclaimed.menu.action` holds the parsed result.
     2. A new menu model is opened: `actionError` shows the stored error.
     3. A menu reopened before completion claims the result through
        `unclaimedChanged`.
     4. A kill and an action both finish while unloaded: both are kept.
     5. A kill with `changed: true` while unloaded: the "press the key
        again" error, and no dialog.
     6. A failed launch while unloaded is kept as an error.
     7. A bar model and a menu model: each gets its own result, and a
        second start in one slot answers `busy:`.

   Verify: `bash tests/app-subscription.sh` and `bash tests/unload.sh` both
   pass locally on p620.

   Traps:
   - Each case uses its own temporary directory.
   - The stub's sleep carries the test's pid, so cleanup kills only its own
     sleeps (the `app-subscription.sh:6` pattern).
4. **Manifest and wording.**
   - `manifest.json:25`: delete the `keepLoaded` line and fix the trailing
     comma on line 24. Set `version` to 1.3.0.
   - Sweep `*.qml`, `README.md` and `tests/` for text saying the menu stays
     loaded, and fix it.

   Verify: `jq -e 'has("keepLoaded")|not' manifest.json` succeeds, and
   `jq -r .version manifest.json` prints 1.3.0.

   Traps: none.
5. **Plugin PR (lead).**
   - Run every check from steps 2-4, plus CI's checks locally: `bash -n`,
     shellcheck, `tests/herdr-sessions.sh`.
   - Commit, push, and open a PR on olafkfreund/nixarchy-herdr that links
     this plan and states the one known loss (none expected) and the
     text-scale risk.
   - Reviews: an Opus review of the diff against this plan, then Codex and
     agy through `second-opinion`. Fix findings.
   - Merge once CI passes.

   Verify: the PR is merged, and `git ls-remote` shows the merge commit on
   `main`.
6. **Pin bump (lead).** `flake.nix:77-80`: set
   `inputs.nixarchy-herdr.url` to the merge commit, and change the comment
   to cite #3139 and the new rev. Run `nix flake lock` for that input only.

   Verify: `jq -r '.nodes["nixarchy-herdr"].locked.rev' flake.lock` shows
   the merge commit, and `just test-host p620` and `just test-host razer`
   build.

   Traps:
   - The comment line must not start with `#3139`; the formatter makes that
     a heading in markdown, and it reads badly in Nix.
   - Never commit in `~/.config/nixos`.
7. **PR, deploy and live checks (lead).**
   - Open the PR from `perf/3139-keeploaded-unload`, linking intent, spec
     and plan. Merge after CI passes.
   - Fast-forward `~/.config/nixos`. Read the bus, post, then run
     `AGENT_BUS_ANNOUNCED=1 just quick-deploy p620`. Then log out and back
     in, which the owner does.
   - Run the spec's p620 checks:
     - `jq .keepLoaded` on the installed manifest is null.
     - After login, `pgrep -af 'hc events --json'` shows one process.
       Opening the menu makes it two, and a toggle-close makes it one.
     - The in-flight `n` then toggle-close creates the session.
     - The bar badge, IPC and click-to-focus work before the first open
       and after an unload.
     - After `Ctrl+=` and a quick toggle-close, the text-scale file holds
       the new size.
     - Look for a shell-side way to list the loaded plugin views. Use it if
       it exists, and record the result in this plan.
   - razer: `just deploy-via-p620 razer`. p510: not without the owner's OK.

   Verify: every check passes, and the results are recorded in the PR.

## Tests

| Where | Command | Expected |
|---|---|---|
| plugin, CI | `for f in tests/*.cjs; do node "$f"; done`, `bash -n`, shellcheck, `bash tests/herdr-sessions.sh` | all pass |
| plugin, local | `bash tests/qml-load.sh` | passes, same allowed-error count |
| plugin, local | `bash tests/app-subscription.sh` | passes |
| plugin, local | `bash tests/unload.sh` | all 7 cases pass |
| this repo | `just test-host p620`, `just test-host razer` | build |
| p620 live | the step 7 checks | all hold |

## Rollback

- **This repo:** revert the step 6 commit, so the pin goes back to
  `c16db87`. Then run `just quick-deploy p620` with a bus announcement.
  `keepLoaded` and the old model return at the next login.
- **Plugin:** revert the merge commit on nixarchy-herdr `main`. Nothing
  else depends on `HerdrActions`.
- **Singleton unworkable** (step 3 case 1 fails): stop. Record it here, and
  propose the spec's fallback (a lazy `Loader` with `keepLoaded` kept) to
  the owner for re-approval. Do not switch to it on our own.
