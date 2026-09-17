---
status: approved
issue: 1872
intent: intent/2026-09-17-1872-nixarchy-apps-per-host-import.md
---

# Spec: read the nixarchy selection from the file apply writes

## Design

Each host imports the selection file `nixarchy-apply` writes for it, and the
flake-root copy is deleted so there is only one layout.

- `hosts/<host>/nixarchy-apps.nix` — the stub apply generates, importing the
  three modules beside it. Byte-identical to apply's own output, so a future
  apply run overwrites it with the same content rather than fighting us.
- `hosts/<host>/nixarchy/{apps,services,advanced}.nix` — copied from that host's
  `~/.config/nixarchy/`, which is the source of truth apply reads.
- `hosts/<host>/nixos/nixarchy.nix` — the import changes from
  `../../../nixarchy-apps.nix` (flake root) to `../nixarchy-apps.nix` (the host
  directory), and the comment above it is replaced: the existing one describes
  the root layout and, on razer, claims only razer imports it.
- `nixarchy-apps.nix` at the root — deleted.

The per-host files for razer and p510 are produced by copying each host's
`~/.config/nixarchy/*.nix` into this clone, not by running `nixarchy-apply` on
each machine. Apply writes into whichever flake clone lives on the host it runs
on, so running it on three machines would scatter the change across three
repositories. The copy is what apply would have written.

## Alternatives rejected

- **Run `nixarchy-apply` on each host and collect the results.** Three clones,
  three sets of local commits to reconcile, and on p510 the apply run ends with
  an offer to rebuild a host we are not allowed to build.
- **Keep the root file as a shared base each host imports alongside its own.**
  Apply has no notion of a shared base, so the root file would be one more file
  it never updates — the same divergence again, with more moving parts.
- **A check in `just validate` asserting each host imports what apply writes.**
  Rejected by the approver in favour of a comment; the automated warning belongs
  upstream in olafkfreund/nixarchy#734.
- **Bumping the nixarchy input in this change.** razer's store path already
  carries Omarchy 4.0.4 against our 4.0.3, so that bump is a desktop version
  change and does not belong inside a layout fix. Separate commit, separately
  revertible.

## Risks

- **p510 loses `dictation`** at its next deliberate rebuild. Intended
  (intent Decisions §1), and p510 is not built or deployed here.
- **razer gains nothing and loses `t3-code`**, which was never installed anyway,
  so its built closure is unchanged by this.
- **p620 gains `brave`**, which is the point, but it is a real closure change on
  the machine the work is being done from.
- A future `nixarchy-apply` run rewrites `hosts/<host>/nixarchy*`. That is now
  correct behaviour rather than drift, provided the import keeps pointing at the
  host directory — which is what the new comment is there to protect.

## Verification

- `nix eval` of `programs.nixarchy.apps` per host shows exactly the intended
  selection: p620 `brave,dictation`, razer `dictation`, p510 empty.
- `just test-host p620` and a razer build both succeed.
- p510: evaluation only. No build, no deploy.
- razer's `~/.config/nixarchy/apps.nix` contains zero malformed `# @` markers.
