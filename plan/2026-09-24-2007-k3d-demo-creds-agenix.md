---
status: approved
issue: 2007
spec: spec/2026-09-24-2007-k3d-demo-creds-agenix.md
---

# Plan: Every factory-cluster Secret comes back on its own after a recreate

## Approved decisions (self-contained)

- **Keep** `factory/azure-demo-creds` and `factory/gcp-demo-creds`, and
  declare them like the other 19 factory Secrets. No new mechanism.
- Each becomes `secrets/factory-secret-<name>.age`, which decrypts to a
  complete Secret YAML (`apiVersion`, `kind`, `type`, `metadata.name`,
  `metadata.namespace`, `data`), the same shape as its siblings.
- Encrypt it in one pipe from the live cluster, so the plaintext never
  touches disk, logs or shell history. Use `age -R` with the siblings' 3
  public keys (`allUsers ++ [ p510 p620 ]`). **Never agenix**, which writes a
  zero-byte file without a TTY.
- `secrets.nix` gets two entries. `modules/containers/k3d.nix` gets both names
  in its two existing literal lists: the step-4b apply loop and `mkSecret`.
- Gate: before committing, each file decrypted with p620's host key must
  `kubectl diff` clean against the live Secret.
- Part 2: after 2026-09-30, delete `/mnt/games/k3d/storage.pre-1497` and
  `/var/lib/k3d-factory/pvc-before.txt`, but only with a healthy cluster and
  all 15 PVCs still on their original PVs.
- Rejected: deleting the creds, factory-gitops SealedSecrets, and
  deduplicating the two lists.

## Steps

1. Recipients: in the worktree,
   `nix eval --json -f secrets.nix '"secrets/factory-secret-odin-api-keys.age".publicKeys' | jq -r '.[]'`
   written to a scratch file (these are public keys) → verify it has 3 lines.
2. For each of `azure-demo-creds` and `gcp-demo-creds`:

   ```sh
   kubectl -n factory get secret "$n" -o json \
     | jq '{apiVersion, kind, type, metadata: {name: .metadata.name, namespace: .metadata.namespace}, data}' \
     | kubectl create --dry-run=client -o yaml -f - \
     | age -R "$RECIPIENTS" -o "secrets/factory-secret-$n.age"
   ```

   → verify the file is non-empty and starts with `age-encryption.org/v1`.
3. **Gate:** `sudo age -d -i /etc/ssh/ssh_host_ed25519_key secrets/factory-secret-$n.age | kubectl diff -f -`
   → no output and exit 0 for both. If a diff appears, stop and do not commit.
4. `secrets.nix`: after the `factory-secret-odin-api-keys` line (306), add both
   entries with `allUsers ++ [ p510 p620 ]`.
5. `modules/containers/k3d.nix`: add `"azure-demo-creds"` and
   `"gcp-demo-creds"` after `"odin-api-keys"` in both lists (lines ~401 and
   ~1078).
   → verify with
   `nix eval .#nixosConfigurations.p620.config.age.secrets --apply builtins.attrNames`
   (both names listed) and a rendered bootstrap that contains both slots.
6. `just check-syntax`, `just test-host p620` → exit 0. Commit, then open a
   PR that links all three artifacts. Merge after CI.
7. Right before the deploy, back up both live Secrets
   (`kubectl get -o yaml`) to a 0600 root file under `/var/lib/k3d-factory/`.
   Then announce on the bus and deploy p620 from a clean `origin/main`
   worktree. → Tests 1–2, then delete the backup.
8. **On or after 2026-09-30:** run Test 3's health check, then
   `sudo rm -rf /mnt/games/k3d/storage.pre-1497 /var/lib/k3d-factory/pvc-before.txt`.
   → `df` on `/mnt/games` gains about 16 GB. Then close #2007.

## Tests

1. `/run/agenix/factory-secret-azure-demo-creds` and
   `…-gcp-demo-creds` exist, 0400 root, non-empty.
2. The bootstrap journal after the deploy applies both slots with
   `unchanged`, and `kubectl -n factory get secret <n> -o jsonpath='{.data}' | sha256sum`
   matches the value taken before step 2.
3. (Step 8) All 37 ArgoCD apps are Synced/Healthy, and the PVC→PV table
   equals `/var/lib/k3d-factory/pvc-before.txt`.

## Rollback

- Before the deploy: drop the branch. Nothing is live.
- After the deploy: revert the PR and deploy. The live Secrets are
  untouched, because the bootstrap only applies, it never deletes, so they
  stay as they are today.
- A bad `.age` value got past the gate: re-apply the step-7 backup
  (`sudo kubectl apply -f` it), then fix the `.age` file.
