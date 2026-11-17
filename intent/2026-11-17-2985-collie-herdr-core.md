---
status: approved
issue: 2985
author: olafkfreund
---

# Intent: Collie through herdr-core

## Problem

Collie (AltanS/collie) is the phone PWA that watches and answers agents over the tailnet. Here it runs
as the Herdr TUI plugin `AltanS/collie` (`docs/applications/herdr.md:43`) and talks to the TUI's socket.
Since #2861 the owner works in herdr-app on top of herdr-core (`hc`). The TUI and the core do not share
agents, so Collie on the phone does not see what the owner is doing in the app. The gap is listed in
`docs/applications/herdr.md:398` ("Collie is not wired to hc") and in the approved spec of #2978
(`spec/2026-11-16-2978-herdr-app-parity.md:309` and `:442`).

Issue #2985 says to wire it up "once that adapter is no longer experimental". That condition is not met.

Upstream status, checked 2026-11-17:

- The Collie README still says Herdr core, tmux and zellij support is experimental
  (<https://github.com/AltanS/collie>).
- `docs/multiplexers.md` says the core adapter has been tested on hc 0.1.14, "a 0.x preview", and that
  Herdr (the TUI) is the primary supported backend
  (<https://github.com/AltanS/collie/blob/main/docs/multiplexers.md>). This repo ships hc 0.1.21
  (`pkgs/herdr-core/default.nix:15`), so it is seven patch releases past the tested one.
- The adapter is moving fast: Collie 1.29.0-edge.4 was published 2026-11-16, and herdr-core issues are
  still open, for example pi panes sharing a folder have no Chat (AltanS/collie issue 780) and a missing
  colour option in the core (<https://github.com/herdrdev/herdr-core/issues/68>).
- Known limits upstream: the mirror has no colour, no rename or focus, no "Show in terminal", no session
  list, no panes from other hc machines, and colour-only dialogs of pi, opencode and Oh My Pi cannot be
  answered from the phone. Claude History and Chat need `collie hooks install claude`.

How Collie is set up here: there is no Nix config for it. The plugin is installed by hand on each host,
and the only Nix trace is `pkgs.bun` in `Users/olafkfreund/profile.nix:210`, which the plugin needs to
build its binary. There is no `COLLIE_MUX` setting anywhere in the repo.

## Proposed outcome

Honest answer: still parked. The issue's own trigger, "no longer experimental", has not happened, and
nothing in this repo can make it happen. No Nix change is proposed now.

What this intent does ask for:

- Keep #2985 open and labelled as waiting on upstream, with one exit test written down: upstream drops the
  "Experimental" note for herdr-core in both `docs/multiplexers.md` and the README. That is upstream
  support status. Whether our pinned hc works with it is a separate, local check, made when the wiring is
  specified (see question 2).
- Re-check on each Collie stable release (not edge) and on each hc bump (`pkgs/herdr-core`).
- When the trigger fires, a later spec covers the wiring: run a second Collie instance (named `hc`)
  with `COLLIE_MUX=herdr-core` next to the TUI one, as upstream describes under "Two Collies on one
  machine", because on a host with the TUI installed Collie keeps `herdr` unless told otherwise. Upstream
  joins the two instances into one crew so that the existing phone entry shows both. The core adapter
  reads only the local core session, so panes of other hc machines are not mirrored (question 7).

Verdict for this run: `still-parked`. Do not write a spec or plan for implementation now.

## Affected users and systems

- The owner, on p620 and razer (the hosts with herdr-app and hc, #2861), who cannot see app-side agents
  from the phone.
- `home/development/herdr.nix` and `home/development/herdr-app.nix` would be touched later, plus
  `docs/applications/herdr.md`. Nothing is touched now.
- p510 is not involved and is never built or deployed for this.

## Constraints

- Subscription logins only, and no secrets in the store (AGENTS.md rules 3 and 6 of Non-negotiable
  apply to any later unit): Collie pairing codes and tokens stay out of Nix.
- Any later service goes in `modules/` or Home Manager with the hardening in AGENTS.md rule 2, or a
  documented exception.
- Collie is single-user and tailnet-only by upstream design; do not expose it wider.
- The TUI plugin must keep working. The core adapter must not replace it while the TUI is in use.
- Collie is installed outside Nix and self-updates; a later spec must decide whether to pin it
  (see open questions 3 and 5).

## Open questions

1. Wait, or try the adapter now by hand? Recommendation: wait. A casual `COLLIE_MUX=herdr-core collie start`
   is not a safe probe: with no `COLLIE_INSTANCE` it targets the default (TUI) instance, upstream persists
   the choice to that instance's `.env` (`cli/mux.ts`), an existing `.env` choice beats the shell variable,
   and `start` manages a service and Tailscale Serve. Also, a plugin install has no `collie` on PATH
   (`docs/install.md`, "Two ways to run it"). If the owner still wants a trial, it needs a separately
   named instance, an explicit binary path and written cleanup steps; it belongs in the later spec.
2. What counts as "no longer experimental"? Recommendation: upstream support status only: the
   "Experimental" note for herdr-core is gone from both `docs/multiplexers.md` and the README. Do not
   require a tested hc version at or past ours; our pin moves, so that could keep the issue parked after
   upstream declares support. May compatibility with our pinned hc be established locally in the later
   spec instead?
3. Edge or stable Collie? Recommendation: stable only. The core adapter changes in every edge release.
4. One Collie or two? Recommendation: two instances (TUI default and `hc`), as upstream documents, until
   the owner stops using the TUI. Decide in the later spec.
5. Keep the imperative plugin install, or consume upstream's package? Upstream exports
   `packages.<system>.collie` (`packaging/nix/collie.nix`): it wraps a checksummed release tarball,
   patches it for NixOS and makes `collie update` decline for a packaged install. No new packaging code
   may be needed. Recommendation: decide in the later spec; nothing changes now.
6. Close #2985 as won't fix? Recommendation: no. Keep it open as parked; the gap is real and upstream is
   active.
7. What must the phone show? Must the existing phone entry show both backends (TUI and core) on both p620
   and razer, which needs two instances joined in one crew, or are separate URLs acceptable? Panes of
   other hc machines are not mirrored by the adapter either way. The answer decides whether merely
   starting a second instance satisfies #2985.

## Decision

Approved by the owner on 2026-11-17, with the recommendation given for each open question above.
