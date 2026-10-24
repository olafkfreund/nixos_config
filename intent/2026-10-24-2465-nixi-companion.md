---
status: approved
issue: 2465
author: olafkfreund
---

# Intent: nixi's snowflake companion runs on p620 and razer

## Problem

nixarchy ships nixi's snowflake desktop companion, off by default
(olafkfreund/nixarchy#1432). Neither host turns it on. nixarchy's docs and
showcase (olafkfreund/nixarchy#1434) need it running on p620 to record the
companion GIF. The owner wants it on both p620 and razer.

## Proposed outcome

Both hosts run the companion. It summons on SUPER+ALT+S, through nixi's
trust levels.

## Affected users and systems

- p620 and razer, through their Home Manager `services.nixi` blocks.
- `flake.lock`, whose nixarchy node moves to an edge that carries #1438.
- p510 is not touched.

## Constraints

- **A p620 switch restarts the nixarchy CI runners** and kills installs in
  flight. Switch only with none queued or running, and announce it on the
  agent bus first.
- **Build razer on p620** (`just deploy-via-p620 razer`).
- **Deploy from `main`,** after the PR merges.

## Open questions

None. The owner pre-approved the intent, spec and plan (2026-10-24).
