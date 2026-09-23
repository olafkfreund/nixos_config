---
status: approved
issue: 2007
author: olafkfreund
---

# Intent: Every factory-cluster Secret comes back on its own after a recreate

## Problem

Two Secrets in the p620 `factory` k3d cluster exist only in the cluster:

- `factory/azure-demo-creds` (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`,
  `AZURE_TENANT_ID`)
- `factory/gcp-demo-creds` (`key.json`)

They are not in agenix and not in factory-gitops. The other 19 factory
Secrets are `secrets/factory-secret-<name>.age` files, seeded by the k3d
bootstrap on every run (`modules/containers/k3d.nix`, step 4b). During
the #1497 recreate these two survived only because they were exported by hand
to a 0600 file and re-applied. The next recreate, or anyone recreating without
knowing, loses them.

Also in #2007: delete `/mnt/games/k3d/storage.pre-1497` (16 GB) and
`/var/lib/k3d-factory/pvc-before.txt` once a week has passed with no data
problems, which is after 2026-09-30. That is a housekeeping step, not a code
change, and needs no spec or plan. It is listed here so the issue closes only
when both parts are done.

## Proposed outcome

- Both Secrets are declared the same way as the other 19: an agenix file
  each, seeded by the bootstrap, and present again after any recreate
  without hand steps.
- Their values are unchanged, so nothing that uses them notices.
- After 2026-09-30 the pre-recreate copy and table are gone and 16 GB is back
  on `/mnt/games`.

## Affected users and systems

- p620 only (the factory cluster). razer and p510 are unaffected. The agenix
  recipients follow the existing `factory-secret-*` entries in `secrets.nix`.
- `modules/containers/k3d.nix` (both name lists), `secrets.nix`, and two new
  `secrets/factory-secret-*.age` files.
- Whatever in the cluster reads these creds (azure/gcp demo workloads).

## Constraints

- **Secret handling:** the plaintext is taken from the live cluster and must
  never land in the repo, the Nix store, a log, or a shell history. Encrypt
  it straight into the `.age` file.
- **Do not create the files with agenix non-interactively.** With stdin not a
  TTY, agenix writes a zero-byte secret. Use `age -R` with the recipients from
  `secrets.nix` (the known repair path).
- The bootstrap re-applies the Secrets on the next p620 deploy. That must be a
  no-op, because the values are identical.
- Deleting the storage copy is irreversible: only after 2026-09-30, and only
  after checking the cluster is healthy.

## Open questions

1. Are these demo creds still wanted at all? Nothing in factory-gitops
   references them. If they are dead, deleting them from the cluster is
   simpler than encrypting them. Recommendation: keep them unless you know
   they're unused. They are cheap to carry, and losing live cloud creds is
   not.
