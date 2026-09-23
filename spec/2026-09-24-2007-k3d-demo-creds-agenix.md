---
status: draft
issue: 2007
intent: intent/2026-09-24-2007-k3d-demo-creds-agenix.md
---

# Spec: Every factory-cluster Secret comes back on its own after a recreate

Decision from the intent approval: **keep** both demo creds (open question 1,
recommendation), and declare them like the other 19.

## Design

Follow the existing `factory-secret-<name>` pattern exactly. No new
mechanism.

1. **Two encrypted files:** `secrets/factory-secret-azure-demo-creds.age` and
   `secrets/factory-secret-gcp-demo-creds.age`. Each decrypts to a complete
   Secret YAML (`apiVersion: v1`, `kind: Secret`, name, namespace `factory`,
   `type`, `data`), the same shape as the existing files (checked:
   `/run/agenix/factory-secret-minio-kms` starts `apiVersion: v1 / kind: Secret`).
2. **Made in one pipe, with the plaintext never on disk:**

   ```sh
   kubectl -n factory get secret <name> -o json \
     | jq '{apiVersion, kind, type, metadata: {name: .metadata.name, namespace: .metadata.namespace}, data}' \
     | kubectl create --dry-run=client -o yaml -f - \
     | age -R <recipients> -o secrets/factory-secret-<name>.age
   ```

   `<recipients>` is a file of the 3 **public** keys, from
   `nix eval -f secrets.nix '"secrets/factory-secret-minio-kms.age".publicKeys'`
   (`allUsers ++ [ p510 p620 ]`, the same as its siblings). It uses `age -R`,
   not agenix: with no TTY, agenix writes a zero-byte secret.
3. **`secrets.nix`:** two entries with the siblings' `publicKeys`.
4. **`modules/containers/k3d.nix`:** add both names to the two existing
   lists, the bootstrap's step-4b apply loop and the `age.secrets`
   declarations (`mkSecret`). They stay two literal lists, as today.

## Alternatives rejected

- **Delete the creds instead.** Rejected at the intent gate: nobody has
  confirmed they are unused, and losing live cloud creds costs more than two
  small files.
- **Put them in factory-gitops** (a SealedSecret or ExternalSecret). The repo
  has neither controller for factory secrets; all 19 come from agenix.
- **One list shared by both places in `k3d.nix`.** That would be a nice
  tidy-up, but it is unrelated to this issue.

## Risks

- **A wrong value** (for example, the `metadata` or `type` changed in
  transit) means the next bootstrap overwrites the live Secret with it. The
  guard: before the deploy, decrypt each new file with a host key and
  `kubectl diff` it against the live Secret. It must show no change.
- **A zero-byte or unreadable `.age` file:** activation fails for that
  secret. Caught by the same decrypt check before the deploy.
- **Deleting the storage copy after 2026-09-30:** irreversible. Do it only
  after confirming the cluster is healthy and all 15 PVCs are still on their
  original PVs.

## Verification

1. Before committing, decrypting each new file with the host key and piping
   it to `kubectl diff -f -`
   (`sudo age -d -i /etc/ssh/ssh_host_ed25519_key <file>`) prints nothing
   for both. Each file is non-empty and has 3 recipients.
2. `just test-host p620` → exit 0. `nix eval` shows both names in
   `age.secrets`.
3. After the p620 deploy: `/run/agenix/factory-secret-{azure,gcp}-demo-creds`
   exist (0400 root). The bootstrap journal shows each applied with
   `unchanged`, and the `.data` hashes match before and after.
4. After 2026-09-30: `/mnt/games/k3d/storage.pre-1497` and
   `/var/lib/k3d-factory/pvc-before.txt` are gone, and `/mnt/games` is about
   16 GB freer.
