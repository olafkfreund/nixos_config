---
status: approved
issue: 2974
author: olafkfreund
---

# Intent: package T3 Code Thememaxed as a Nix Omarchy plugin (parked check, 2026-11-17)

This note only re-checks the blocker. The full intent stays in
`intent/2026-11-16-2974-t3code-thememaxed.md` and is not rewritten.

## Problem

The owner parked Issue #2974 on 2026-11-16 until T3 Code 0.1.10 is stable
and nixpkgs `t3code` reaches it. Has that happened?

## Proposed outcome

Verdict: **still-parked**. The upstream half of the blocker has cleared;
the nixpkgs half has not.

Evidence, checked 2026-11-17:

- Upstream: T3 Code v0.1.10 is a stable release, not a pre-release, published
  2026-11-17T01:44Z (`gh release list -R pingdotgg/t3code`;
  <https://github.com/pingdotgg/t3code/releases/tag/v0.1.10>). Cleared.
- nixpkgs: the bump PR is still open and unmerged (`state` OPEN, `mergedAt` null):
  <https://github.com/NixOS/nixpkgs/pull/589125> ("t3code: 0.1.8 -> 0.1.10").
  Not cleared.
- This repo: the root `nixpkgs` input is `nixpkgs_7` (`flake.lock` line 3780), tracking
  `nixos-unstable` and locked to `d5cc6833999746cffdfe0598f7bc801a57b887a9` (line 3527).
  `pkgs/by-name/t3/t3code/unwrapped.nix` line 46 at that revision declares `version = "0.1.8"`,
  so p620 has 0.1.8. A merge into master does not reach `nixos-unstable` at once, and
  this repo then needs a `nix flake update` to pick it up.
- Thememaxed upstream moved since the reviewed commit `38ca154`: five newer
  commits, ending at `515b509` "Version 1.2.1" (2026-11-17), with no release
  or tag on the repo. So the pin and the review in the old intent are stale
  (<https://github.com/jagrat7/omarchy-t3code-thememaxed/commits/main>).

## Affected users and systems

No change today. p620 stays on T3 Code 0.1.8 with the plain `omarchy`
theme from Issue #2973. Razer and p510 are unaffected.

## Constraints

- Do not override nixpkgs `t3code` to pin 0.1.10 by hand; the owner chose
  to wait (open question 0, option b).
- When resuming, re-review all of Thememaxed from `515b509` or newer
  (publisher, every `.qml`, `themed/t3code.css.tpl`) before pinning.

## Open questions

1. Resume now? Recommendation: no. Resumption requires 0.1.10 in this repo's configured
   package set (the `nixos-unstable` input after a lock update), not only on master.
   Wait for PR 589125 to merge and for `flake.lock` to move past it; then refresh the old intent, rebase the
   Thememaxed review on the v1.2.1 or newer commit, and ask for approval.
2. Should the owner relax the park and accept option (a), an `overrideAttrs`
   to 0.1.10? Recommendation: no; that PR is small and likely to land soon,
   and a source build of an Electron app is not worth the churn.
3. Re-check trigger: `gh pr view 589125 -R NixOS/nixpkgs --json state,mergedAt` (a closed,
   unmerged PR does not count), then, after the next flake update:
   `nix eval --raw --no-write-lock-file .#nixosConfigurations.p620.pkgs.t3code.version`.
   Do not use `nixpkgs#t3code`: the machine's registry resolves `nixpkgs` to a system
   store source, which a lock update in this repo does not change.

## Decision

Approved by the owner on 2026-11-17, with the recommendation given for each open question above.
