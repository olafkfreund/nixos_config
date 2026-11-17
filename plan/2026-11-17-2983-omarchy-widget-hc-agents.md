---
status: approved
issue: 2983
spec: spec/2026-11-17-2983-omarchy-widget-hc-agents.md
coders:
  2: codex # small tricky bash: first-line reader that returns on the newline and keeps the byte cap
  3: codex # jq turn rule with a label-absent fallback; same author as step 4 so the one jq block stays consistent
  4: codex # one-line jq count change plus the two-case test, in the same block as step 3
  5: coder # QML look of the stale mark and the panel visibility condition; wiring, no tricky logic
  6: codex # retry timer with a bounded count; small stateful QML logic
  7: coder # docs row removal and a short section; mechanical
reviewers:
  - codex # independent read of the fork diff (QML and tests) and of the pin route against this plan
  # agy: out of use by owner decision (#2748)
---

# Plan: Omarchy herdr widget shows herdr-app (hc) agents

Branch `feat/2983-omarchy-widget-hc-agents`, worktree `~/.config/nixos-2983`. This repo carries only the pin route, the
docs and the live check (steps 11 to 14). The code lives in `olafkfreund/nixarchy-herdr`, local checkout
`~/Source/GitHub/nixarchy-herdr`, branch `feat/22-herdr-core-app` (tip `b14b503`, manifest 1.1.0, 15 commits ahead of
`master` `9c8a8fa`, unpushed). Its own intent, spec and plan (Issue 22, all approved) govern the original work; steps 1
to 10 only close the gaps below and land it. "Lead" steps (builds, reviews, pushes, merges, deploys, commits, live
checks) are not handed to a coder.

## Approved decisions (from the spec)

- **D1** Track fork Issue 22. Do not replace it with upstream `jankeesvw/omarchy-herdr` PR 18 (merge commit
  `5a935a0`, one "Desktop app" row from `hc ls`). Record PR 18 as "reviewed, not merged, ported by design" with
  `git merge -s ours 5a935a0`, as `c3f654d` did for `b00a6ca` (Issue 21). The new `app-*` code stays additive.
- **D2** State per row. Window open: status from `herdr-app ls`. Window closed: `hc` state with the herdr-app v0.1.16
  turn contract. `blocked` or `error` needs you; `working` is working; otherwise (`idle`, `done`) the row is done when
  `turn > labels["herdr.seen"]`, else idle. Only when the `herdr.seen` label is absent: `done` shows as `idle` if
  `~/.config/herdr-app/view.json` `attention[address]` is `{word:"done", seen:true}`. A missing label is not 0.
  Accepted edge, only in the fallback: a second finish after a seen one reads as seen (fork risk R1).
- **D3** Keep the subscription: `hc events --json` as a change signal, 250 ms coalescing, 40 s watchdog, snapshot read
  by `app-list`. It is valid only once the snapshot reader returns at once (G6). Fallback, inside the fork, only if
  the live check shows a leaked process or stuck stream: the existing poll plus a bounded `app-list`.
- **D4** An agent is a live terminal whose `status` object is non-null (`state` in idle, working, done, blocked,
  error). Plain shells and finished terminals are never agents. Do not require an `agent` field (the real snapshot has
  none). Connected-machine terminals (`razer/t4`) never reach the bar or its counts: `app-list` emits `machine == ""`
  rows unless `--remote`; the model keeps `appHostSessions` empty unless the menu asks. Remote rows are menu-only.
- **D5** Pin route is a nixarchy bump, not an override. Lock nodes: `nixarchy-herdr` (root `nixarchy`, branch `edge`,
  rev `ea4c5e0`) is at `9c8a8fa` and is the one hosts install; `nixarchy-herdr_2` (via meetingai) is `affd9854`, left
  alone. Fork merge, tag `v1.1.0` (label only; the pin stays a full rev), then nixarchy PR per
  `docs/internals/flake.md` "Bumping the pin", then here `nix flake update nixarchy`. Fallback only if the bump is slow
  or its delta unsafe: `inputs.nixarchy.inputs.nixarchy-herdr.url = "github:olafkfreund/nixarchy-herdr/<rev>"` in
  `flake.nix` beside `nixarchy-omatheme` (line 74), comment naming Issue 2983 and "remove once nixarchy pins this
  commit or later".
- **D6** Kill, interrupt and prompt are in as built: `K` confirms and names the sub-agents ending with it, re-asks if
  the cascade changed, runs `hc kill ADDR` for one terminal. No row-level kill, never closes a space, never stops the
  server.
- **D7** Failure is visible. `hc` absent (`startFailed`): no app rows, no retries, no cost (the p510 case). `hc`
  present but stream or `app-list` fails: rows read "not live", kill and interrupt refused, error line shows
  `appError`, tooltip says "herdr-core not reachable". `error` counts with blocked and takes the urgent colour.
  Window open the row word is `blocked` (herdr-app maps it); window closed the raw `error` is kept.
- **D8** `manifest.json` stays 1.1.0.
- **Gaps to close in the fork before merge:** G1 count `error` as blocked in the app projection only (not the classic
  counter at about line 712); G2 stale badge visible unconditionally, never green; G5 turn-aware status (D2);
  G6 snapshot reader returns on the first newline; G7 one bounded retry after a failed `app-list`; G3 history note;
  G4 already holds (address regex `^([A-Za-z0-9][A-Za-z0-9._-]{0,31}/)?t[0-9a-z]{1,9}$`, every hc call under
  `bounded`, plain-string rendering, no shell given untrusted text, demo writes are no-ops, classic path unchanged
  without `hc`), so it is a checklist item only.
- **Not doing:** replacing the scope with PR 18; merging PR 18 as well; `hc ls` poll only; raw `done`; always
  `herdr-app ls`; remotes in the bar; an override of the herdr input first; adding `hc` and `herdr-app` to the plugin
  packages (revisit only if step 14 check 6 fails); upstream-style tag numbering.
- Per owner rule: no build or deploy on p510 without asking; deploys follow the bus rule; the owner logs out and in
  (no `omarchy-restart-shell` over SSH as proof).

## Steps

Fork steps run in `~/Source/GitHub/nixarchy-herdr` on `feat/22-herdr-core-app` (do not add a second worktree of the same
branch). Line numbers are those of tip `b14b503` and drift as earlier steps land; search by name.

- **Step 1 (lead):** fork repo, whole branch: `git fetch --multiple origin upstream`, rebase onto `origin/master`, then
  run the full baseline before touching anything and record the result. Also `git fetch` the upstream PR 18 merge
  `5a935a0` and confirm a trial `git merge --no-commit 5a935a0` conflicts only in `bin/herdr-sessions`, `Card.qml`,
  `Panel.qml` (abort it; `-s ours` in step 8 makes this moot). Check: `for f in bin/herdr-sessions bin/herdr-menu-keys
  tests/herdr-sessions.sh; do bash -n "$f"; done; shellcheck bin/herdr-sessions bin/herdr-menu-keys
  tests/herdr-sessions.sh; bash tests/herdr-sessions.sh; node tests/session-actions.cjs; bash tests/app-subscription.sh;
  omarchy plugin validate .` all pass. Traps: never run against the real `hc` or herdr-app UI; the tests use fakes. Tell
  the owner if the rebase conflicts (fork spec risk R1) rather than guessing.
- **Step 2 (G6):** `bin/herdr-sessions` `app_snapshot()` (line 249 onward, the `head -c "$((TOTAL_BYTE_CAP + 1))" <
  "$RUN_DIR/hc-events" | head -n 1` line): replace the pipe so the reader returns on the first newline and stays bounded
  in bytes: `head -n 1 < "$RUN_DIR/hc-events" | head -c "$((TOTAL_BYTE_CAP + 1))"` (the second `head` closes the pipe
  after CAP + 1 bytes, so the first gets SIGPIPE). Do not capture a bare `head -n 1` and check the size afterwards: that
  reads the whole line into memory first (measured by the reviewer: 16 MiB captured before an 8 MiB cap check). Keep the
  `over_byte_cap` check on the result; `bounded 3` limits time only. Keep `kill_tree`, `JOB_PIDS`, the fifo cleanup and
  the `die "could not read herdr-core"` paths. Add a case to `tests/herdr-sessions.sh`: a stub `hc events --json` prints
  one valid snapshot line, then `sleep 5`; `app-list` returns valid JSON in under 1 s and `pgrep -f` finds no orphan
  stub afterwards. Add an oversized-line case: a stub printing more than `TOTAL_BYTE_CAP` bytes with no newline (then a
  newline) makes `app-list` die with "could not read herdr-core" and its memory stays near the cap. Check: the new case
  `ok`, plus the Step 1 command set. Traps: shellcheck clean; the test must clean up its background sleeper (the file
  already tracks background pids near line 16); no `readarray` quirks, bash only; text stays plain.
- **Step 3 (G5):** `bin/herdr-sessions` jq in `app-list`, `displayStatus` (lines 317 to 325, the
  `$attention[.address]` rule): implement D2. Use `.turn` and `.labels["herdr.seen"]` when the label exists: raw
  `blocked`/`error`/`working` keep their word; raw `idle` or `done` becomes `done` when `turn > seen`, else `idle`.
  When the label is absent keep the existing `attention` rule (`done` plus `{word:"done", seen:true}` becomes `idle`).
  Window-open `$appStatus` precedence stays first. Treat the label as a number (it may arrive as a string; compare
  numerically, and an unparsable value counts as absent). Tests in `tests/herdr-sessions.sh`: raw `idle` with
  `turn > seen` gives done; raw `done` with `turn <= seen` gives idle even when `attention` says seen for an older
  turn; no label falls back to `attention`; window open ignores all of it. Check: `bash tests/herdr-sessions.sh`.
  Traps: the snapshot fixture must carry `turn` and `labels` (schema-shaped, from live `hc events --json | head -1`);
  jq heredoc is single-quoted (`<<'JQ'`), keep it so; line width is not enforced in bash, keep it readable.
- **Step 4 (G1):** same file, the `kind:"app"` projection (line 341 onward, `blocked:`): count
  `.status == "blocked" or .status == "error"`. Leave the classic counter at about line 712 untouched. Tests: window
  closed, one raw `error` agent gives `blocked: 1`; window open, an `error` agent that the fake `herdr-app ls`
  reports as `blocked` gives `blocked: 1`; a `razer/t4` terminal never appears in `sessions` without `--remote` and
  never in the counts. Check: `bash tests/herdr-sessions.sh`. Traps: do not touch `HerdrModel.qml` colours here (the
  per-row colour at about line 891 already exists).
- **Step 5 (G2):** `HerdrModel.qml` `badgeColor()` (line 934) and `Panel.qml` badge `visible:` (line 236,
  `herd.reachable && herd.runningCount > 0 && herd.badgeActive`). While `appStale`, a failure mark is shown
  unconditionally: also before any successful snapshot and with zero active agents; the colour is not
  `root.finished` (green). The fork picks the look (colour, suffix or a mark on the icon). Keep `tooltipText()` line
  968. The mark must not appear when `hc` is absent (`startFailed`; D7). Tests: `tests/session-actions.cjs`
  `badgeColor()` while stale; `tests/app-subscription.qml` the panel visibility condition with stale and zero agents,
  and stale before the first snapshot. Check: `node tests/session-actions.cjs; bash tests/app-subscription.sh`.
  Traps: no QtMultimedia or other imports the shell lacks (an import failure kills the whole shell); keep the
  visibility condition testable as a model property so the headless test can read it.
- **Step 6 (G7):** `HerdrModel.qml` `applyAppList()` (line 1163, the failure branch at 1175 sets `appStale` only) and
  `appLine()` (line 1110, heartbeats do not refresh). On failure start a retry timer: a few seconds, a small fixed
  count, then stop and wait for the next real event or the watchdog restart. A success resets the count and clears
  `appStale` (when `appSubLive`). Do not retry when `startFailed`. Test in `tests/app-subscription.qml`: the stub
  `app-list` fails once then succeeds, only heartbeats arrive, `appStale` clears. Check:
  `bash tests/app-subscription.sh`. Traps: the retry must not stack timers across watchdog restarts; the stub file is
  `tests/app-subscription.sh` heredocs (add a fail-once counter there, remove the sleeper in its `trap`).
- **Step 7:** `README.md` (the "desktop app" section) and the fork's `plan/2026-11-16-22-herdr-core-app.md`: add one
  short paragraph on the stale mark, `error` counting and the turn rule with the label-absent fallback; add a
  "Deviations" line in that plan naming G1, G2, G5, G6, G7 (each is a recorded deviation in the same commit as its
  code, so fold each line into the commit of steps 2 to 6 rather than one docs commit). Check: `markdownlint` clean
  if the fork has it; otherwise read it once. Traps: line starting with a hash plus digits becomes an H1, write
  "Issue 22"; no inline HTML.
- **Step 8 (lead):** fork repo: record upstream PR 18 (G3): `git merge -s ours 5a935a0` with a message in the style of
  `c3f654d` ("Record upstream 5a935a0 (PR 18) as reviewed, not merged; ported by design in Issue 22", with the
  per-commit handling). Re-run the Step 1 command set, plus the read-only live checks from the spec on p620:
  `hc ls --json`, `hc events --json | head -1`, `herdr-app ls; echo $?` (2 with the window closed),
  `jq '.attention|length' ~/.config/herdr-app/view.json`, `time bash bin/herdr-sessions app-list` (well under 1 s,
  valid JSON, `pgrep -fc 'hc events'` unchanged), `bash bin/herdr-sessions app-list --remote | jq '.machines'`
  (razer connected, no `razer/` rows by default). Traps: starts nothing; never stop the real core.
- **Step 9 (lead):** fork repo: review, then push and PR. Fresh `model: opus` agent given only this plan path and
  `git diff master...`; codex on QML and tests (`reviewers:`). Agent output is advice. Then `git push -u origin
  feat/22-herdr-core-app`, open the PR (body: `Closes #22`, the gap list, test output), verify the remote head matches,
  let CI (`.github/workflows/ci.yml`) pass, and merge only on the owner's go-ahead. Tag the merge commit `v1.1.0`
  (`v1.0.0`, `v1.2.1`, `v1.2.2` exist; the odd order is accepted) and record `<herdr-merge-sha>`. Traps: pushing and
  merging another repo is a lead action; verify the push landed by comparing heads (`git ls-remote`).
- **Step 10 (lead):** nixarchy repo, `~/Source/GitHub/nixarchy` (use a worktree, branch from `origin/edge`): follow
  `docs/internals/flake.md` "Bumping the pin" (line 704 onward). Read `gh api
  repos/olafkfreund/nixarchy-herdr/compare/9c8a8fa...<herdr-merge-sha>`, edit the rev at `flake.nix` line 262, run `nix
  flake lock`, then `git diff flake.lock` must touch `nixarchy-herdr` alone. Check: `nix build
  .#checks.x86_64-linux.menu-verbs .#checks.x86_64-linux.options-files .#checks.x86_64-linux.plugin`, then resolve the
  plugin source in the nixarchy worktree: `nix eval --raw --impure --expr '(builtins.getFlake (toString
  ./.)).inputs.nixarchy-herdr.outPath'` and check there (`checks.plugin` is a NixOS test, not the plugin directory):
  `grep -c app-list bin/herdr-sessions` non-zero, `jq .version manifest.json` gives `1.1.0`. Whether the packaged copy
  drops `intent/` and `tests/` is shown in step 14 on the installed tree. PR to `edge` titled like the previous bump
  (nixarchy PR 1813, "bump nixarchy-herdr to 9c8a8fa"); merge on the owner's go-ahead and record `<nixarchy-merge-sha>`
  (the merge commit on `edge`). Traps: build on p620; the `menu-verbs` check does not cover the new verbs (dash in
  `herdr-app do`, `hc` unmatched), so it passing is not evidence for them.
- **Step 11 (lead):** this repo, pin: confirm `gh api repos/olafkfreund/nixarchy/compare/<nixarchy-merge-sha>...edge -q
  .behind_by` prints `0`. Run `nix flake update nixarchy` and read `git diff flake.lock`: it moves everything nixarchy
  moved since `ea4c5e0`, not only herdr. Read the `edge` commits in between (`gh api
  repos/olafkfreund/nixarchy/compare/ea4c5e0...edge`). If the delta is unrelated and risky, or the nixarchy bump is
  slow, revert the lock and use the D5 fallback in `flake.nix` (add the input line next to line 74, then `nix flake
  lock --update-input nixarchy-herdr` in the override form the flake accepts, or `nix flake lock`). Check: `git diff
  flake.lock` is as read. Traps: `nixarchy-herdr_2` must stay at `affd9854`; an override of a source-only input does
  not poison the cache, but a nixarchy bump can pull other overlays, so read the lock diff before building.
- **Step 12:** `docs/applications/herdr.md`: delete the Known gaps row at line 400 ("Omarchy `nixarchy.herdr` widget
  still reads the TUI", Issue 2983); add a short section under "Herdr app (herdr-app + hc)" (line 341), before "Known
  gaps" (line 394): what counts as an app agent (live terminal with a status object), one row per space, remote rows
  menu-only, `a` prompt, `i` interrupt, `K` kill with the sub-agent confirm, the window-closed turn rule, and the "not
  live" and stale mark. Do not edit the approved `spec/2026-11-16-2978-herdr-app-parity.md` ("Gaps"); docs are the
  current truth. Check: `pre-commit run markdownlint --hook-stage pre-push --files docs/applications/herdr.md` (the hook
  runs at pre-push only). Traps: lines at most 120 characters, tables exempt; a line starting with a hash plus digits
  becomes an H1, write "Issue 2983"; no inline HTML outside backticks; no nav change, so `mkdocs.yml` and
  `mkdocs-full.yml` stay as they are.
- **Step 13 (lead):** this repo, build and commit: `git merge origin/main` first (a stale deploy rolls main back),
  then `just check-syntax`, `just test-host p620`, and for razer `just build-on-p620 razer` (build only; not
  `deploy-via-p620`, which switches and needs main). Never build or deploy p510. Commit with
  `feat(herdr): bump nixarchy for herdr-app agents in the Omarchy widget (Issue 2983)` style subject and the issue
  number; the pre-commit and pre-push formatters (alejandra, statix, deadnix, markdownlint, shellcheck) must pass, and
  write the body to a file for `--body-file` (the bus guard greps command text). Open the PR linking intent, spec and
  plan. Check: `git diff origin/main --stat` shows only `flake.lock`, `docs/applications/herdr.md` (and `flake.nix`
  only on the fallback) plus the three artifacts.
- **Step 14 (lead):** deploy and live check, only after the owner approves the plan and the PR is reviewed. Run
  `read_new("#agents:freundcloud.org.uk")`, `post` what and how long, then `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1
  just p620` and `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`. Then the spec's in-repo
  checks: (5) `nix eval --raw --impure --expr` `'(builtins.getFlake (toString
  ./.)).inputs.nixarchy.inputs.nixarchy-herdr.outPath'` gives a store path whose `bin/herdr-sessions` contains
  `app-list`; resolve the installed plugin (`readlink -f` under `~/.config/omarchy`, or `omarchy plugin list`), then
  prove the host closure uses that tree and not the meetingai node: `nix path-info -r /run/current-system | grep -i
  herdr` must list the installed path, and the installed tree passes `grep -c app-list bin/herdr-sessions` non-zero, `jq
  .version manifest.json` is `1.1.0`, `intent/` and `tests/` absent. Compare the `nixarchy-herdr` outPath above with the
  lock's `nixarchy-herdr_2` rev `affd9854` to show the second node is not the one installed. (6) `tr '\0' '\n' <
  /proc/$(pgrep -xo quickshell)/environ | grep '^PATH='` contains `/etc/profiles/per-user/olafkfreund/bin` (use the real
  shell process name if it differs); if not, take the packages route from "Not doing". Then hand the owner the by-hand
  list (logout and login first, `OMARCHY_PATH` is frozen at login): blocked/working/done colours, window closed keeps an
  unseen finish and clears when seen, Enter focuses (and starts the app when closed), `a` `i` `K` on throwaway `hc run`
  terminals only, stale state with a failing `hc` wrapper on the shell `PATH` (never stop the real core), `hc run --on
  razer` menu-only, `i` does nothing on a classic row. p510 only if the owner OKs a deploy: no app rows, no errors, no
  extra process. Traps: p620 and razer need a logout; a "no change" before it is not proof; check `pgrep -fc 'hc
  events'` after opening and closing the menu (fork spec R5: growth means fall back per D3); razer exit 4 from syncthing
  is cosmetic (see memory).

## Tests

- Fork, every step: `bash -n` and `shellcheck` on `bin/herdr-sessions`, `bin/herdr-menu-keys`,
  `tests/herdr-sessions.sh`; `bash tests/herdr-sessions.sh` (existing cases plus G1, G5, G6 and the remote case);
  `node tests/session-actions.cjs` (G2 `badgeColor()`); `bash tests/app-subscription.sh` (G2 visibility, G7 retry,
  coalescing, watchdog, restart); `omarchy plugin validate .`. Also a missing `hc` (stub `PATH` without it) leaves
  classic rows unchanged and adds no stale mark.
- nixarchy: the lock diff touches `nixarchy-herdr` only; the three checks in step 10 build.
- This repo: `just check-syntax`, `just test-host p620`, `just build-on-p620 razer`, markdown lint on the docs file,
  the pre-push hooks.
- Live, read-only, p620: the commands in step 8. Owner by hand: the list in step 14.

## Rollback

- Fork: nothing is pushed until step 9; before that, `git stash push -u -m 2983-rollback` (keeps unrelated work), then
  `git reset --hard b14b503` in the fork (a mixed `git reset` would leave the edits in the tree). After merge, revert
  the merge PR and re-pin.
- nixarchy: revert the bump PR on `edge` (a one-line rev plus lock change back to `9c8a8fa`).
- This repo: revert the PR (`flake.lock`, docs, and `flake.nix` if the fallback was used), then redeploy p620 and razer
  with the bus announcement, or `nixos-rebuild switch --rollback` on a host whose bar misbehaves; log out and in to load
  the old plugin. The previous plugin tree is not affected by app code when `hc` is missing, so p510 needs nothing.
- If the live check fails on subscription cost (D3 fallback), do not leave the faulty subscription deployed: either
  implement and verify the poll variant in the fork and re-pin before keeping the bump, or revert the pin PR (and
  redeploy with the bus announcement) at once, then ship the poll variant as the follow-up.
