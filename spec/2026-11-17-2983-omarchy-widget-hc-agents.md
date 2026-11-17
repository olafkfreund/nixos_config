---
status: draft
issue: 2983
intent: intent/2026-11-17-2983-omarchy-widget-hc-agents.md
---

# Spec: Omarchy herdr widget shows herdr-app (hc) agents

## Design

### Shape of the work

Issue #2983 tracks the integration of an existing, approved branch. It does not write new widget code.

- **Code:** `olafkfreund/nixarchy-herdr`, local branch `feat/22-herdr-core-app` (tip `b14b503`, manifest 1.1.0,
  15 commits ahead of master `9c8a8fa`, not pushed). Its intent, spec and plan are all `status: approved`
  (`spec/2026-11-16-22-herdr-core-app.md`, `plan/2026-11-16-22-herdr-core-app.md`).
  Issue #22 in that repo is open. I read the branch, not only its docs; section "Checked against the code" says what
  I found.
- **This repo:** the pin route (D5), the docs row, and the live check. Nothing else.
- **Upstream** `jankeesvw/omarchy-herdr` PR #18 (merge commit `5a935a0`, also the current upstream HEAD,
  <https://github.com/jankeesvw/omarchy-herdr/pull/18>) is a compatibility reference only (D1).

### Decisions

Each is the owner's approved recommendation, settled here.

**D1. Track Issue #22; do not replace it with PR #18.**
Issue #22 is approved, implemented and tested, and it covers per-space rows, a subscription, controls and remotes.
PR #18 gives one "Desktop app" row built from `hc ls`. The fork records PR #18 in its upstream-history note as
"reviewed, not merged, ported by design", the way `c3f654d` recorded upstream `b00a6ca` for Issue #21. This stops
the next upstream sync from re-merging it over the new `app-*` code in `bin/herdr-sessions`, `Card.qml`, `Panel.qml`.
Upstream stays able to take it: the new code is additive and needs no change to classic sessions.

**D2. State source: the Issue #22 attention design, not a blanket downgrade.**
Per row, with the window open, the status comes from `herdr-app ls`. With it closed, `hc` state is used and the
turn contract of herdr-app v0.1.16 applies
(<https://github.com/herdrdev/herdr-app/blob/v0.1.16/docs/labels.md>, section `herdr.seen=<turn>`): `blocked` or
`error` needs you; `working` is working; otherwise (`idle`, `done`) the row is done when `turn > herdr.seen`, else
idle. Core's snapshots carry `turn` and `labels` for every terminal (the doc says so; `hc ls --json` shows `turn`).
Only when the `herdr.seen` label is absent does the fallback apply: `done` shows as `idle` when
`~/.config/herdr-app/view.json` `attention[address]` is `{word:"done", seen:true}`. A missing label is not 0.
So an unseen finish stays visible with the window closed, and a seen one clears, including a raw `idle` that the
old rule would hide. The branch does not do this yet: `bin/herdr-sessions` line 321 reads only `attention`
(gap G5). Checked live: `view.json` exists, has an `attention` map of 41 entries, and `herdr-app ls` exits 2 with
the window closed. Accepted edge, only in the no-label fallback: a second finish after a seen one can read as
seen (the record has no turn number). That is risk R1 of the fork spec, checked live in step 7.

**D3. Subscription, not polling.**
Keep `hc events --json` as a change signal, a 250 ms coalescing timer, a 40 s watchdog, and a snapshot read by
`app-list`. I measured first, as the intent asked, on p620 (hc 0.1.21, herdr-app 0.1.16): `hc ls --json` takes
about 0.01 s, the first line of `hc events --json` is 24 KB for 32 terminals (30 finished), and `herdr-app ls`
fails fast when closed. A 3 s bounded poll would be cheap too, so the choice is not forced by cost. I keep the
subscription because it is implemented and tested, and it should make a blocked agent turn the badge at once
rather than after up to 3 s. That holds only once the snapshot reader returns at once (gap G6: today
`app_snapshot()` takes 3 s against a silent producer, measured). If the QML check or step 7 shows a leaked
process or a stuck stream, the fallback is the
existing poll plus a bounded `app-list`, done inside the fork. That fallback is a small change to `HerdrModel.qml`
and does not change `app-list`.

**D4. Which terminals are agents, and remotes.**
An agent is a live terminal whose `status` object is non-null (`state` in idle, working, done, blocked, error).
Plain shells (null status) and finished terminals are never agents. Checked live: the real snapshot has no `agent`
field at all, one live terminal reports `status.state = "idle"` (this Claude session), and one live shell has
`status = null`. So a rule that required an `agent` name would hide real agents, and the fork's rule is right.
Terminals of connected machines (`address` like `razer/t4`; `hc machine ls` shows `razer` connected) never reach
the bar or its counts. `app-list` emits only `machine == ""` rows unless `--remote` is passed, and the model keeps
`appHostSessions` empty unless the menu asks. Remote rows are menu-only.

**D5. Pin route: a nixarchy bump, not an override.**
The lock shows two herdr nodes, and the intent's "both at `affd9854`" is wrong:

| Lock node | Reached through | Rev |
| --- | --- | --- |
| `nixarchy-herdr` | root `nixarchy` (rev `ea4c5e0`, branch `edge`) | `9c8a8fa` |
| `nixarchy-herdr_2` | `nixarchy-meetingai` -> `nixarchy_2` (rev `5ef30a9`) | `affd9854` |

Hosts install the root one. nixarchy declares it as a rev-pinned `flake = false` input at `flake.nix` line 262
on `edge`, and `modules/home.nix` `herdrSessions` copies it and removes `intent/ spec/ plan/ tests/`. Steps:

1. Merge the fork PR for Issue #22. Tag the merge commit. Existing tags are `v1.0.0`, `v1.2.1`, `v1.2.2` (the last
   two are upstream's); use `v1.1.0` to match manifest 1.1.0, and accept the odd order. The pin stays a full rev;
   the tag is a label for people.
2. In nixarchy, follow `docs/internals/flake.md` "Bumping the pin" (line 704 onward): read
   `gh api repos/olafkfreund/nixarchy-herdr/compare/9c8a8fa...<merge>`, edit the rev, run `nix flake lock`
   (the lock diff must touch `nixarchy-herdr` alone), then build `checks.menu-verbs`, `checks.options-files`
   and `checks.plugin`. Merge so that `edge` has it (previous bumps: nixarchy PR 1813, "bump nixarchy-herdr to
   9c8a8fa").
3. Here: confirm `edge` contains it
   (`gh api repos/olafkfreund/nixarchy/compare/<merge-sha>...edge -q .behind_by` is `0`), run
   `nix flake update nixarchy`, and read the lock diff. It moves everything nixarchy moved since `ea4c5e0`,
   not only herdr. Read the `edge` commits in between; if the delta is unrelated and risky, use the fallback.
4. Drop the "Omarchy `nixarchy.herdr` widget still reads the TUI" row from `docs/applications/herdr.md`
   ("Known gaps", line 396). Add a short section on app rows (what counts, `i` and `K` keys, "not live"). Also fix
   the "Gaps" entry in `spec/2026-11-16-2978-herdr-app-parity.md` only if the owner wants history rewritten;
   default is to leave approved specs alone and let the docs be the current truth.

Fallback, used only if the nixarchy bump is slow or its delta is unsafe: in `flake.nix`, next to the
`nixarchy-omatheme` line (`inputs.nixarchy-omatheme.url = ...`), add
`inputs.nixarchy.inputs.nixarchy-herdr.url = "github:olafkfreund/nixarchy-herdr/<merge-rev>"` with a comment
naming Issue #2983 and "remove once nixarchy pins this commit or later". The input is a plain source tree, so
the overlay cache-poisoning trap (a deep package changed) does not apply; only the plugin copy rebuilds. The
meetingai copy (`nixarchy-herdr_2`) is left alone: it is not the one hosts install. I have not proven it is unused,
so step 5 of Verification looks at the installed path.

**D6. Kill, interrupt and prompt are in.**
As approved in Issue #22: `K` asks for confirmation that names the sub-agents ending with it (`die_with_parent`
cascade), re-asks if the cascade changed, and runs `hc kill ADDR` for one terminal only. App rows have no
row-level kill, so a space is never closed. The server is never stopped. Intent outcome 4 stands.

**D7. Failure is visible, and `error` counts as needing you.**

- `hc` absent (`startFailed`): no app rows, no retries, no cost. This is the p510 case.
- `hc` present but the stream or `app-list` fails: rows stay, read "not live", kill and interrupt are refused,
  the error line shows `appError`, and the tooltip says "herdr-core not reachable".
- A real `error` status counts with blocked and takes the urgent colour. With the window open, herdr-app maps
  `error` to `blocked` itself (`src/model.rs` line 596 at v0.1.16,
  <https://github.com/herdrdev/herdr-app/blob/v0.1.16/src/model.rs#L596>), and the fork prefers that status, so
  the row word is `blocked`. With the window closed the raw word `error` is kept and does not count yet (gap G1).
  Precedence: window open, the app status; window closed, the raw status.
- The bar badge itself must show staleness, visible even with no agents, not only the tooltip (gap G2).
- A failed `app-list` while the subscription is healthy must recover without a new event (gap G7).

**D8. Version.** `manifest.json` 1.1.0, tag as in D5 step 1.

### What must be true of the fork branch to merge

Gaps I found, to be closed on `feat/22-herdr-core-app` before its PR merges. Each is a small change in the
fork under its own plan; if the fork owner objects, it is recorded as a deviation in its `plan/`.

- **G1, `error` counting.** The app projection in `bin/herdr-sessions` (the `kind:"app"` row, `blocked:` at about
  line 341) counts only `status == "blocked"`. Line 712 is the classic-session counter: leave it. In the app
  projection count `error` in `blocked`, so the badge text "waiting on you" and the urgent colour cover it.
  Tests, both cases: window closed, one raw `error` agent gives `blocked: 1`; window open, an `error` agent that
  `herdr-app ls` reports as `blocked` gives `blocked: 1`. The badge is urgent in both. Per-row colour already
  exists (`HerdrModel.qml`, status colour at line 891).
- **G2, stale badge.** `badgeColor()` (line 933) ignores `appStale`; only `tooltipText()` (line 968) mentions it.
  Also `Panel.qml` line 236 hides the badge unless `herd.reachable && herd.runningCount > 0 && herd.badgeActive`,
  so with no snapshot yet, an empty snapshot or zero active agents there is no badge to recolour. Required: while
  `appStale`, a visible failure mark shows unconditionally (a different colour, a suffix, or a mark on the
  icon; the fork picks the look), including before any successful snapshot and with zero active agents, and it
  must not be green. Tests: `badgeColor()` while stale (`tests/session-actions.cjs`), and the panel visibility
  condition with stale and zero agents, and stale before the first snapshot (`tests/app-subscription.qml`).
- **G5, turn-aware status with the window closed.** Replace the `{word, seen}`-only rule at line 321 with the
  rule in D2: use `turn` and `labels["herdr.seen"]` when the label exists, the `attention` fallback only when it is
  absent. Tests: raw `idle` with `turn > seen` shows done; raw `done` with `turn <= seen` shows idle, even when
  `attention` says `{done, seen:true}` for an older turn; no label falls back to `attention`.
- **G6, snapshot reader returns at once.** `app_snapshot()` (line 249) pipes `head -c CAP | head -n 1`; the first
  `head` keeps waiting after the first line, so a silent producer holds it for the full `bounded 3`. Reproduced:
  an immediate first line then silence took 3.007 s. Use a first-line reader that returns on the newline and still
  enforces the byte cap (for example `head -n 1` first, then the cap check on the result, since `bounded` already
  limits time). The fork picks the form. Test: a stub `hc events` that prints one line then sleeps 5 s makes
  `app-list` return in under 1 s with no orphan. The existing QML test stubs `app-list`, so it cannot catch
  this; put the test in `tests/herdr-sessions.sh`.
- **G7, retry after a failed `app-list`.** `applyAppList()` (`HerdrModel.qml` line 1163) sets `appStale` and
  schedules nothing, and `appLine()` (line 1110) ignores heartbeats for refresh, so one failed read on a quiet
  core leaves rows stale and actions refused. Add one bounded retry: on failure, start a timer (a few seconds,
  a small fixed count, then wait for the next real event or the watchdog restart). Test: `app-list` fails once,
  then succeeds, with only heartbeats arriving; `appStale` clears.
- **G3, history note.** Record upstream PR #18 as reviewed and ported by design (D1).
- **G4, the rest already holds** and is part of the merge checklist, not new work: valid address
  `^([A-Za-z0-9][A-Za-z0-9._-]{0,31}/)?t[0-9a-z]{1,9}$`, every hc call under `bounded`, text rendered as
  plain strings, no shell handed untrusted text, demo mode makes `app-*` writes no-ops, and the classic path is
  unchanged when `hc` is missing.
- **Process:** push the branch, open the PR from it, review per the fork plan (fresh Opus on plan plus
  `git diff master...`, codex on QML and tests, agy on `bin/herdr-sessions`), then step 7 live on p620 and razer.
  Agent output is advice; the lead and owner approve.

### Checked against the code

- Pinned `9c8a8fa` has no `hc` or `herdr-app` code (matches the intent). The branch adds `app-list`, `app-focus`,
  `app-prompt`, `app-interrupt`, `app-kill`, `app-new`, `valid_hc_address`, `appSubProc`, `appStale`.
- The plugin's declared tools are only `herdr`, `jq`, `iproute2` (`modules/home.nix` line 2354 onward in nixarchy).
  `hc` and `herdr-app` are not packaged for it. They come from the user's profile, which this repo provides
  (`Users/olafkfreund/profile.nix` lines 206-209, p620 and razer). So the Omarchy shell's `PATH` must contain
  `/etc/profiles/per-user/olafkfreund/bin`; Verification 6 checks it. This is the only way the widget can read as
  "no hc" on a host that has it.
- nixarchy's `menu-verbs` check greps `\bherdr (session|api|agent) <sub>`. `herdr-app do` has a dash, so it is
  not matched; `hc` calls are not matched either. The check keeps passing but also does not cover the new verbs,
  which the fork's fakes and step 7 cover instead.

## Alternatives rejected

- **Replace the scope with upstream PR #18.** One row for the whole app, polling with a downgrade of `done`,
  and no per-space rows, controls or remotes. It would throw away an approved, tested design and would
  conflict with the fork's own `bin/herdr-sessions` anyway.
- **Merge PR #18 as well as Issue #22.** Two implementations of one feature in the same functions.
- **`hc ls` poll only.** Works and is cheap (0.01 s), but the CLI summary has no parent, label or status object
  (the fork spec's finding), and a poll adds a lag the subscription does not have. Kept as the documented fallback.
- **Show raw `done` from `hc ls`.** `done` never clears there, so the badge would stick green.
- **Always use `herdr-app ls`.** Fails when the window is closed, which hides unseen finishes.
- **Remotes in the bar.** `razer` is connected now; its agents would double count with razer's own bar.
  Menu only, later.
- **Override the herdr input here first.** Faster but hides the change from nixarchy and leaves a second pin to
  remove. Only the fallback in D5.
- **Add hc and herdr-app to the plugin's packages in nixarchy.** Would give the bar a fixed `PATH`, but changes
  the closure on every nixarchy host. Not needed while the profile provides them; revisit if Verification 6 fails.
- **Tag with the upstream numbering.** Would need a manifest bump to 1.2.3 or higher for no benefit.

## Risks

- **R1, the fork branch is unpushed.** It may have drifted from master or conflict with upstream PR #18
  (`bin/herdr-sessions`, `Card.qml`, `Panel.qml`). Rebase on `origin/master` and rerun every test before the PR.
- **R2, new hc and herdr-app versions.** They change weekly. The fakes use schema-shaped objects; step 7 reruns on
  what is deployed. A failed live check blocks the merge.
- **R3, the nixarchy bump drags other changes** from `edge` into this flake (D5 step 3). Read the lock diff.
- **R4, session `OMARCHY_PATH` is frozen at login.** A switch does not load the new plugin until logout and login
  (`docs/architecture/desktop.md`, line 286). A "no change" after deploy is not proof of a bad build.
- **R5, a stuck subscription.** Four idle `hc events` processes, one per bar model, on three monitors. Heartbeats
  are 15 s. The watchdog restarts a dead one. If `pgrep -fc 'hc events'` grows after a menu open and close, fall
  back per D3.
- **R6, `error` and `blocked` merge.** One badge number now means "needs you" for both. Accepted. The row word is
  `blocked` with the window open (herdr-app maps it) and `error` with it closed.
- **R7, kill takes children with it.** The confirm names them; the fork's tests cover grandchildren, shells and
  `die_with_parent: false`. Live check uses throwaway terminals only.
- **R8, host cost.** razer and p620 each deploy a new plugin and need a logout. p510 has no herdr-app; it gets the
  new tree but has no `hc`, so it must show no app rows and no new cost.
- **R9, the second lock node** (`nixarchy-herdr_2`) stays at `affd9854`. Harmless if unused; confirmed by step 5.

## Verification

### In the fork (before merge; the lead runs these in a worktree of `nixarchy-herdr`)

```bash
for f in bin/herdr-sessions bin/herdr-menu-keys tests/herdr-sessions.sh; do bash -n "$f"; done
shellcheck bin/herdr-sessions bin/herdr-menu-keys tests/herdr-sessions.sh
bash tests/herdr-sessions.sh          # existing cases plus the app cases, all ok
node tests/session-actions.cjs        # all PASS
bash tests/app-subscription.sh        # the qs check: coalescing, watchdog, restart
omarchy plugin validate .
```

New cases required by G1, G2, G5, G6 and G7: an `error` agent counts as blocked, window open and closed; a stale
app row makes the badge show the stale mark, also with zero agents and before the first snapshot; turn-aware
status with and without the `herdr.seen` label; `app-list` returns in under 1 s against a silent producer; a failed
`app-list` recovers on heartbeats alone; a missing `hc` (stub `PATH` without it) leaves classic rows unchanged
and adds no stale mark.
Also assert: a `razer/t4` terminal never reaches `sessions` without `--remote`, and never reaches the bar counts.

### Live, read-only, on p620 (the lead may run these; they start nothing)

- `hc ls --json` and `hc events --json | head -1`: confirm the schema facts in D4 (status object, no `agent`).
- `herdr-app ls; echo $?`: 2 with the window closed.
- `jq '.attention|length' ~/.config/herdr-app/view.json`.
- `time bash bin/herdr-sessions app-list` from the fork checkout: valid JSON, well under 1 s (needs G6), and
  `pgrep -fc 'hc events'` returns to its earlier value (no orphan producer).
- `bash bin/herdr-sessions app-list --remote | jq '.machines'`: `razer` connected, no `razer/` rows in the
  default output.

### In nixarchy (the PR that moves the pin)

- `git diff flake.lock`: only `nixarchy-herdr` changes.
- `nix build .#checks.x86_64-linux.menu-verbs .#checks.x86_64-linux.options-files .#checks.x86_64-linux.plugin`.
- Open the built plugin tree: `grep -c app-list <plugin>/bin/herdr-sessions` is non-zero, `intent/` and `tests/` are
  absent, and `jq .version <plugin>/manifest.json` gives `1.1.0`.

### In this repo (after the bump)

1. `gh api repos/olafkfreund/nixarchy/compare/<merge-sha>...edge -q .behind_by` prints `0`.
2. `nix flake update nixarchy`, then `git diff flake.lock`: read it (D5 step 3).
3. `just check-syntax`, `just test-host p620`, `just test-host razer` (or `just build-on-p620 razer`, build only).
   Not `just deploy-via-p620 razer`: it runs `nixos-rebuild switch` and needs main, so it belongs to the announced
   deploy stage only. Never build or deploy p510 without the owner's OK.
4. Docs: the Known gaps row is gone and the new section reads right. The markdown lint hook passes. No nav change,
   so `mkdocs.yml` and `mkdocs-full.yml` stay as they are.
5. Which tree the host uses:
   `nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixarchy.inputs.nixarchy-herdr.outPath'`
   gives a store path whose `bin/herdr-sessions` contains `app-list`. Adjust the attribute path if the flake
   does not expose nested inputs. The installed plugin is not that path: nixarchy copies the source into a new
   derivation (`herdrSessions`, `modules/home.nix` line 419), removes files and patches shebangs. So compare the
   installed plugin (`readlink -f` in `~/.config/omarchy`, or where `omarchy plugin list` says) with the evaluated
   plugin `src` of this flake's nixarchy (`modules/home.nix` line 2347), then check content:
   `grep -c app-list bin/herdr-sessions` is non-zero and `jq .version manifest.json` is `1.1.0`. The meetingai
   copy (`nixarchy-herdr_2`) is shown unused only if the installed tree has the new `app-list` and the evaluated
   `src` was built from the root node.
6. The shell's `PATH` has `hc`:
   `tr '\0' '\n' < /proc/$(pgrep -xo quickshell)/environ | grep '^PATH='` contains the per-user profile bin.
   (Use the real shell process name if it differs.) If not, take the packages route in "Alternatives rejected".

Deploys and restarts follow the bus rule in `AGENTS.md`: read `#agents`, post, then run with
`AGENT_BUS_ANNOUNCED=1`. No `omarchy-restart-shell` over SSH as a proof; the owner logs out and in.

### Only the owner can check by hand (p620 and razer, after logout and login)

1. With herdr-app open, an agent in a space shows as one row named after the space, next to the classic sessions.
   Blocked turns the badge red, working amber, done green.
2. Close the window: an unseen finish stays green; look at it in the app, and it clears. Mind R1 (a second finish).
3. Enter on an app agent focuses it. With the window closed, it starts the app and focuses it.
4. `a` sends a prompt; `i` interrupts; `K` asks `End <title>?` naming sub-agents, and ends only that terminal.
   Use throwaway `hc run` terminals and leave the real agents alone.
5. Stale state: with `hc` temporarily unusable (for example a wrapper on the shell's `PATH` that exits 1), rows read
   "not live" and the badge shows the stale mark. Never stop the real core to test this.
6. `hc run --on razer ...` shows in the menu only, never in the bar count.
7. p510 (only if the owner OKs a deploy): no app rows, no errors, no extra process.
8. The `i` key does nothing on a classic row.
