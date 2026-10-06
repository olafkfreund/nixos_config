---
status: approved
issue: 2187
author: olafkfreund
---

# Intent: factory services get a valid Claude credential, and keep it

## Problem

Since the k3d cluster on p620 was rebuilt on 2026-10-04 (Issue #2156),
aifactory, pfactory and tfactory have had no valid Claude credential. Their
`cred-sync` sidecars refuse the seed once a minute ("seed expires
2026-08-20T17:06:05Z, already past … refusing to adopt"), so any task that
needs Claude fails to authenticate.

The `factory/factory-cli-creds` Secret is seed-only (Factory#861). Bootstrap
writes it only when it is missing; after that the cluster is meant to keep
it fresh. When a cluster is recreated, bootstrap re-seeds it from the agenix
slot `secrets/factory-secret-factory-cli-creds.age`. That slot was last
written on 2026-08-20 (#1398), and the credential in it expired the same
day. A seed that is already expired cannot be rotated, so every recreate
lands the factories in this state. #2156 only exposed it.

`cred-sync` refusing an expired seed is correct (Factory#628) and is not the
problem.

## Proposed outcome

- aifactory, pfactory and tfactory authenticate to Claude again, and their
  `cred-sync` sidecars stop logging refusals.
- A cluster recreate never seeds a credential that is already expired, or
  if it would, the bootstrap says so loudly instead of applying it.

## Affected users and systems

- p620 only: the `factory` namespace of the k3d cluster, plus
  `modules/containers/k3d.nix` (bootstrap seeding) and the agenix slot.
- Possibly the `factory-gitops` repo, if whatever keeps the Secret fresh
  lives there.
- codex, copilot and gemini credentials share the same Secret
  (`codex-auth.json`, `copilot-apps.json`, `gemini-oauth_creds.json`) and may
  be stale the same way.

## Constraints

- Subscription login only, never an API key (#1831).
- Secrets load at runtime only. Never put a credential in the Nix store.
- Do not weaken `cred-sync`'s refusal logic (Factory#628).
- Rotating an agenix secret must not wipe it: agenix overwrites `$EDITOR`
  when stdin is not a TTY, so use the `age -R` path.
- Announce on the agent bus before restarting factory pods.

## Open questions

1. Where should a fresh credential come from: the host's own
   `~/.claude/.credentials.json` (valid, refreshed by the Claude CLI), or a
   dedicated login made for the factory?
2. Should the fix keep the agenix copy fresh (a periodic re-encrypt), stop
   relying on agenix as the seed and copy from the host at bootstrap, or
   both?
3. Do the codex, copilot and gemini entries need the same fix now, or only
   Claude?

## Decisions at approval

The user approved on 2026-10-06 with the recommended answers to every open
question, as listed in the session reply.
