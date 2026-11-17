---
status: approved
issue: 2983
author: olafkfreund
---

# Intent: Omarchy herdr widget shows herdr-app (hc) agents

Follow-up to `intent/2026-11-16-2978-herdr-app-parity.md`, which accepted this as a gap.
The code change is in the separate repo `olafkfreund/nixarchy-herdr`, not in this repo.
This repo holds the intent, spec and plan, and later the flake pin bump.

## Problem

Since Issue #2861, p620 and razer run the Herdr desktop app (`herdr-app`) on herdr-core (`hc`)
next to the classic Herdr TUI. The two run separate servers and do not share agents.

The Omarchy bar widget `nixarchy.herdr` only reads the classic servers. It runs `herdr session list --json`
and `herdr api snapshot` (`bin/herdr-sessions`, `cmd_list`). It has no mention of `hc` or `herdr-app`
(`grep -c` gives 0 in both `bin/herdr-sessions` and `HerdrModel.qml` at the pinned rev).

The owner works in the app now. So an agent in the app that is blocked, or done, never turns the bar badge
red or green, and the menu cannot land on it. (At the pinned rev, blocked is red, working is amber and
done is green: `HerdrModel.qml` line 67, `herdr.done` defaults to `#5FA46B`.) The widget exists to show exactly that
signal.

The gap is listed in `docs/applications/herdr.md` ("Known gaps") and in
`spec/2026-11-16-2978-herdr-app-parity.md` ("Gaps").

## Proposed outcome

This is "do it", not "wait" and not "won't fix". It is mostly integration of work that already exists:
the fork's local branch `feat/22-herdr-core-app` has an approved plan
(`plan/2026-11-16-22-herdr-core-app.md`, status approved) and 15 commits ahead of master, through `b14b503`
(manifest 1.1.0). `git branch -r --contains b14b503` is empty: it is not pushed or merged. Issue #2983 therefore
tracks getting Issue #22 reviewed, merged and pinned here, unless the owner chooses to replace its scope.

1. `nixarchy.herdr` shows herdr-app agents next to the classic sessions. They feed the badge counts and
   colours (blocked, done, working) like any other agent.
2. The data comes from `hc ls --json`. Each terminal has `address`, `agent`, `status`, `where`
   ("space / tab") and `cwd`. Which terminals count as agents is a contract the spec must verify against live
   `hc ls` output. Upstream selects live terminals with a nonempty status and falls back to the title `agent`
   when the `agent` field is absent (`bin/herdr-sessions` `app_row`, upstream rev 5a935a0, lines 602-634).
   Requiring an `agent` field could hide a terminal that reports status without a name.
3. Picking an agent focuses it in the app with `herdr-app do agent.focus` (starting the app if it is
   closed), the same action our `freund-agents` mod uses (`mods/freund-agents/main.js:124`).
4. The widget stays safe: no polling storm, timeouts on every call, addresses validated before use, nothing
   handed to a shell. Any kill never stops the herdr-core server. Whether kill is in this change is open
   question 6. If it is, it protects unrelated work and asks for confirmation that names the sub-agents that end
   with it, because an hc child can have `die_with_parent` and ending a parent ends its children
   (fork intent `intent/2026-11-16-22-herdr-core-app.md`, line 95).
5. Failure is visible. When `hc` is unreachable the badge and menu must not read as "nothing needs attention".
6. The new nixarchy-herdr revision lands here as a flake pin bump, and `docs/applications/herdr.md` drops
   the known-gap row.

Prior art decides the shape, so the spec should reuse it:

- Upstream already has this. `jankeesvw/omarchy-herdr` Issue #17 was closed by PR #18, merged 2026-11-16
  (<https://github.com/jankeesvw/omarchy-herdr/pull/18>). It adds one "Desktop app" row built from `hc ls`,
  reads agent state from `herdr-app ls` when the app runs, and focuses with `herdr-app do agent.focus`.
- Our fork, `olafkfreund/nixarchy-herdr`, synced upstream in its PR #25 (2026-11-16), but that sync stops
  before PR #18, so master has no hc code. The unmerged local branch `feat/22-herdr-core-app` does.
- The fork already has an approved design and an implementation for this: Issue #22 "Show herdr-core / herdr-app
  agents, one row per space"
  (<https://github.com/olafkfreund/nixarchy-herdr/issues/22>). It differs from upstream in two ways: one
  row per app space instead of one row for the whole app, and a long-running `hc events --json` with a
  debounced `hc ls` instead of polling.

## Affected users and systems

- The owner, on p620 and razer, where `herdr-app` and `hc` are installed. p510 has no herdr-app.
- Repo `olafkfreund/nixarchy-herdr`: `bin/herdr-sessions` (1100 lines of bash), `HerdrModel.qml`,
  `Card.qml`, `Panel.qml`, `Menu.qml`, `tests/`, `manifest.json`. Baselines differ by revision: the pinned `affd9854`
  has manifest 1.0.0, calls `timeout`
  directly (`bin/herdr-sessions` lines 151, 350) and polls every 3 s open, 5 s active, 20 s idle
  (`HerdrModel.qml` line 907). Fork master has manifest 1.0.2 and a `bounded` helper (line 177).
- This repo: `flake.lock` entries `nixarchy-herdr` and `nixarchy-herdr_2` at rev `affd9854...`. They are
  transitive inputs, not declared in `flake.nix`, so the pin is controlled through the nixarchy input.
- `docs/applications/herdr.md` (Known gaps table, line 396).
- Other users of the upstream plugin are not affected, but a fork change should stay mergeable upstream.

## Constraints

- The code change goes in nixarchy-herdr, with its own intent/spec/plan, branch and PR. Its repo already has
  `intent/`, `spec/` and `plan/` directories. This repo only carries the pin bump.
- The QML bar runs inside the Omarchy shell and polls every 3 to 20 seconds, by state. An `hc` call must be bounded in
  time,
  and an unreachable or absent `hc` must not slow or blank the classic sessions (fork master wraps calls in
  `bounded`; the pinned rev uses `timeout`).
- `hc ls` reports the raw core state. Upstream notes that `done` never clears there, unlike `herdr-app ls`
  which knows what you have seen. Showing raw `done` would leave the badge stuck.
  The fork's approved spec reads `~/.config/herdr-app/view.json` `attention` for this
  (`spec/2026-11-16-22-herdr-core-app.md`, line 37, and risk R1 at line 296).
- `herdr-app do` needs the app window: with no window it fails ("no Herdr window ... Connection refused").
  Focus must handle that case.
- Agent titles, `where`, `cwd` and addresses are untrusted data. Validate addresses (Issue #22 uses
  `^t[0-9a-z]{1,9}$`) and render text as plain strings.
- Keep the demo mode and the test suite (`tests/herdr-sessions.sh`) working. Add tests for the
  hc path using a fake `hc` on `PATH`.
- No secrets, no builds or deploys on p510, no API keys. Verifying means a build on p620 and then
  a logout and login: `OMARCHY_PATH` keeps the old tree, so an Omarchy shell restart does not load the new
  plugin (`docs/architecture/desktop.md`, line 286). Verify against the new plugin source, or document a proven
  way to load it directly. Deploys and restarts follow the bus rule in `AGENTS.md`.
- `hc ls` may list terminals from connected machines. They must not reach the local bar while remotes are
  out of scope (open question 4).

## Open questions

1. Does #2983 track integration of the fork's approved Issue #22 branch, or replace its scope with upstream PR #18?
   Recommendation: track Issue #22. It is approved, implemented and tested, and covers per-space rows,
   subscriptions, controls and remotes. Use PR #18 only as a compatibility reference. Needs the owner's answer
   before the spec.
2. Which state source: `hc ls` alone, or `herdr-app ls` when the app runs?
   Upstream uses `herdr-app ls` when the app is up and keeps the raw status when it is not. Showing raw `done`
   as "live" with the window closed would hide newly finished work. Must unseen completion stay visible with
   the window closed, and how does a seen completion clear?
   Recommendation: decide with the Issue #22 attention design (`view.json`), not a blanket downgrade.
3. Polling or `hc events --json`?
   Issue #22's approved plan already uses a subscription with a watchdog. Recommendation if it is dropped:
   start with the existing 3 second poll plus a bounded `hc ls` (simple, same as classic
   sessions). Move to `hc events` only if the cost shows up. The spec should measure `hc ls` latency first.
4. Remote machines (`hc machine ls`, `hc ls` showed a connected `razer`)?
   Issue #22 addresses machine identity. Recommendation: out of scope for the bar in the first change; the
   spec must say how connected-machine terminals are filtered out of the local counts. The widget already has its own
   `--host` ssh path for
   classic sessions. Add hc remotes only in the menu, never the bar, as a later step.
5. How does the new rev reach this flake, given the input is transitive through nixarchy?
   Recommendation: check how nixarchy pins it (`flake.lock` line 2203 area) and prefer a nixarchy bump.
   Fall back to a `follows`/override only if the bump is slow, and note the cache-poisoning risk of overrides.
   The spec must decide this before the plan.
6. Are kill, interrupt and prompt in this change?
   Issue #22's approved plan includes them, with a confirm dialog that names affected sub-agents.
   Recommendation: take them as approved there. If the owner wants focus only, say so, and drop the kill
   promise in outcome 4.
7. Failure and error states.
   When `hc` is unreachable: stale rows, an error line, or nothing? How does the real `error` status count and
   colour in the badge? Recommendation: show an error line, never silence; count `error` with blocked.
8. Version and release: bump `manifest.json` to 1.1.0 and tag?
   Recommendation: yes, a feature bump, so the pin in this repo names a tagged state.

## Decision

Approved by the owner on 2026-11-17, with the recommendation given for each open question above.
