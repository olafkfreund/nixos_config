---
status: approved
issue: 1872
author: olafkfreund
---

# Intent: the nixarchy app selection is written per-host and imported from the root

## Problem

`nixarchy-apply` chooses where to write the app selection based on the hostname:
if `hosts/<hostname>/` exists it writes there, otherwise it falls back to the
flake root. Our three hosts all import the root copy:

```
hosts/p620/nixos/nixarchy.nix:25    ../../../nixarchy-apps.nix
hosts/razer/nixos/nixarchy.nix:25   ../../../nixarchy-apps.nix
hosts/p510/nixos/nixarchy.nix:26    ../../../nixarchy-apps.nix
```

So on 2026-09-17 apply wrote `hosts/p620/nixarchy-apps.nix` plus
`hosts/p620/nixarchy/{apps,services,advanced}.nix`, and nothing imports any of
them. They are also untracked, which on its own would make them invisible to the
flake.

The result is not an obvious break. The root file is still imported and still
holds the older selection, so the app set **freezes**: apps enabled before the
layout drift keep working, apps enabled after it never build. `brave` was
enabled from the menu, copied by apply, reported as applied, and installed by
nobody, while `dictation` carried on working from the root file.

Two upstream defects kept it quiet, both now filed:

- olafkfreund/nixarchy#720 — apply stages flake-root paths even when it wrote
  under `hosts/<hostname>`, leaving the copies untracked. Fixed upstream on
  2026-09-16; our pinned rev `ebe93dd` (2026-09-14) predates the fix.
- olafkfreund/nixarchy#734 — the "nothing imports it" warning greps for the
  filename anywhere in the flake, so our stale root-level import satisfies it
  and the warning never fires. Open.

The comment at `hosts/p620/nixos/nixarchy.nix:18-22` records this same class of
failure being fixed once before, for p620, when the import line was missing
entirely. This is its recurrence by a different route: the line exists, and now
points at the wrong place.

### It is two hosts, not one

razer is in the same state, and was found only by checking. Its
`~/.config/nixarchy/apps.nix` enables `dictation` **and `t3-code`**, while razer
builds from the root file, which carries `dictation` alone. So `t3-code` was
enabled, applied, and installed by nobody — the same silent freeze as `brave` on
p620, on a host with no drifted files in the flake to give it away.

### What each host actually has

Read on 2026-09-17. This is what decides whether moving a host is neutral:

| Host | Own `~/.config/nixarchy/apps.nix` | Built today (root file) | Move is |
| --- | --- | --- | --- |
| p620 | `brave`, `dictation` | `dictation` | a gain: `brave` |
| razer | `dictation`, `t3-code` | `dictation` | a gain: `t3-code` |
| p510 | *nothing enabled* | `dictation` | **a loss: `dictation`** |

p510 is the one host the move takes something away from: its own selection is
empty, so pointing it at a per-host file removes dictation from it. That loss is
accepted deliberately (Decisions §1) rather than papered over — dictation was
not wanted on p510. It is recorded here because it must be a decision, not a
side effect nobody noticed.

### razer's markers are malformed

razer's lines read `# @ dictation` and `# @ t3-code`, with a space between the
hash and the at-sign. Upstream matches `#@` exactly
(`grep -qE "#@ $id([[:space:]]|$)"`, nixarchy `modules/apps.nix:1218`), so the
Omarchy menu cannot see either entry: it reads them as absent and will append a
fresh line rather than toggle the one that is there. Independent of the import
bug, and worth repairing in the same change since it is the same file.

## Proposed outcome

- What `nixarchy-apply` writes on a host is what that host's configuration
  imports, with no manual step after using the menu.
- Enabling an app from the Omarchy menu and applying results in that app being
  built on the next rebuild, on p620 and razer.
- `brave` is installed on p620 — the one stranded selection being redeemed.
- `dictation` is still installed on p620 and razer. On p510 it goes away, by
  decision, at that host's next deliberate rebuild.
- `t3-code` is not installed anywhere, and its line no longer sits enabled in a
  file that nothing reads.
- The Omarchy menu on razer can toggle razer's existing entries instead of
  appending duplicates.
- The files apply writes are tracked, so the flake can see them.
- The trap is written down where the next person meets it, in each host's
  `nixarchy.nix`, alongside the note about its previous incarnation.

## Affected users and systems

- **p620** — has the drifted files in the flake, and `brave` stranded.
- **razer** — no drifted files in the flake, but `t3-code` is stranded just the
  same, and its markers are malformed. Heavy rebuild.
- **p510** — same stale import line, own selection empty, so it is the one host
  the move would take something away from. Never built or deployed without
  asking first.
- `hosts/*/nixos/nixarchy.nix`, the root `nixarchy-apps.nix`, and the nixarchy
  flake input.
- Only user: olafkfreund. No service or secret is involved.

## Constraints

- Must not lose a selection by accident. The root file's `dictation.enable` is
  live on all three hosts; p620 and razer carry it in their own files already,
  so it survives for them. p510's loss of it is the one intended subtraction.
- The per-host files exist only on p620. razer's and p510's have to be generated
  by running `nixarchy-apply` on each host, because apply writes only for the
  machine it runs on (`uname -n`). This is not a three-line edit.
- Must not build or deploy p510 as part of this. Config change only, applied
  whenever p510 is next deployed deliberately.
- Must leave the tree in a state where `nixarchy-apply` is correct going
  forward, not merely repaired once — including the nixarchy input bump, or
  #720 will keep leaving files untracked.
- Explicit imports only (AGENTS.md §5); no `readDir` over `hosts/*/nixarchy/`.
- razer is a heavy rebuild: build on p620 via `just deploy-via-p620 razer`.

## Decisions

Answered by the approver on 2026-09-17. Open questions: none.

1. **p510 moves, and loses dictation.** Its own selection is empty and stays
   empty; dictation was not actually wanted there. It stops being installed on
   p510 at the next deliberate p510 rebuild, which this change does not perform.
2. **The root `nixarchy-apps.nix` is deleted.** Every host reads only its own
   file. `nixarchy-apply` has no notion of a shared base, so anything left at
   the root is a file it would never update again.
3. **The guard is a comment**, in each `hosts/*/nixos/nixarchy.nix`, next to the
   existing note recording the previous incarnation of this trap. No check in
   `just validate`; upstream nixarchy#734 is where the automated warning
   belongs.
4. **`t3-code` stays uninstalled.** Its line is removed from razer's own
   `apps.nix` rather than carried into the per-host file, so the layout change
   does not quietly install software nobody missed.
