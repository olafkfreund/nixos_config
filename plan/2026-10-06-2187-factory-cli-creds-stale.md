---
status: draft
issue: 2187
spec: spec/2026-10-06-2187-factory-cli-creds-stale.md
---

# Plan: factory services get a valid Claude credential, and keep it

## Approved decisions (carried from the spec)

- **Credential source.** A dedicated factory login,
  `CLAUDE_CONFIG_DIR=<tmp> claude auth login` (subscription, never an API
  key). Never the host's `~/.claude/.credentials.json`: a shared refresh
  token chain means the host and the cluster invalidate each other.
- **Re-seed now.** Patch the live `factory/factory-cli-creds` Secret and
  re-encrypt the agenix slot with the same credential.
- **Keep fresh.** A root timer `factory-cli-creds-snapshot` copies the live
  Secret to `/var/lib/k3d-factory/factory-cli-creds.json` (0400), every 4 h
  at :30. The `cred-broker` CronJob runs at `0 */4 * * *`. The copy is
  taken only when the Claude `expiresAt` is in the future and later than
  the existing snapshot.
- **Recreate.** The seed-only branch applies whichever of the snapshot and
  the agenix slot has the later Claude expiry. If that seed is expired, it
  still applies it but logs `[k3d-bootstrap] ERROR: factory-cli-creds seed
  expired at <date>`.
- **Codex, Copilot and Gemini.** Check their expiries; fix only if trivial.
- `cred-sync` refusal logic is not touched (Factory#628).

## Facts the steps rely on

- **Agenix slot.** `secrets/factory-secret-factory-cli-creds.age`, with
  recipients `allUsers ++ [ p510 p620 ]` at `secrets.nix:277`. It decrypts
  to a YAML `Secret` (`kind: Secret`, `name: factory-cli-creds`,
  `type: Opaque`). Its `data` keys are `claude-credentials.json`,
  `codex-auth.json`, `copilot-apps.json` and `gemini-oauth_creds.json`.
- **Claude expiry.** It is at `.claudeAiOauth.expiresAt`, in milliseconds.
- **Seed-only branch.** It sits at `modules/containers/k3d.nix:431-441`
  inside `bootstrapScript` (runtimeInputs include kubectl, jq and
  coreutils, but not yq). Its `$f` is `/run/agenix/<slot>`.
- **Backup unit pattern.** `k3d.nix:935-976` (`skillai-db-backup` and its
  timer) is the pattern to copy: root oneshot,
  `path = with pkgs; [ kubectl coreutils ]`,
  `environment.KUBECONFIG = cfg.kubeconfigPath`,
  `after = [ "k3d-cluster-bootstrap.service" ]`, and
  `mkIf cfg.argocd.enable`.

## Steps

1. **Fresh login (the user; interactive).** In a terminal:
   `export CD=$(mktemp -d); CLAUDE_CONFIG_DIR=$CD claude auth login`, then
   complete the browser flow. Check: `jq '.claudeAiOauth.expiresAt' $CD/.credentials.json`
   is in the future.
   Traps: subscription login only (#1831). Never touch `~/.claude`.

2. **Patch the live Secret (runtime).** Write a merge patch to a 0600 file
   in the scratchpad:
   `{"data":{"claude-credentials.json":"<base64 -w0 of $CD/.credentials.json>"}}`.
   Then run
   `kubectl -n factory patch secret factory-cli-creds --type merge --patch-file <file>`
   and shred the patch file.
   Then `kubectl -n factory create job cred-broker-manual-2187 --from=cronjob/cred-broker`.
   Check:
   - The Job succeeds, and its log shows a new expiry.
   - Within 2 min, `cred-sync` in aifactory, pfactory and tfactory logs
     adoption and stops refusing.

   Delete the manual Job afterwards. Also record the codex, copilot and
   gemini expiries (decode each key and read its expiry field) for the PR.
   Traps:
   - Never pass the secret in argv.
   - The bus guard matches the word "restart" in commands; no restart is
     needed here.

3. **Re-encrypt the agenix slot (repo).** Build the manifest from the live
   Secret:
   `kubectl -n factory get secret factory-cli-creds -o json | jq '{apiVersion,kind,type,metadata:{name:.metadata.name},data}'`,
   written to a 0600 tmp file.
   Get the recipients with
   `nix eval --json -f secrets.nix '"secrets/factory-secret-factory-cli-creds.age".publicKeys' | jq -r '.[]'`,
   also into a tmp file. Then run
   `age -R <recipients> -o secrets/factory-secret-factory-cli-creds.age <manifest>`
   and shred the tmp files. Delete `$CD`.
   Check:
   - This prints a future expiry:

     ```bash
     sudo age -d -i /etc/ssh/ssh_host_ed25519_key \
       secrets/factory-secret-factory-cli-creds.age \
       | jq -r '.data["claude-credentials.json"]' | base64 -d \
       | jq .claudeAiOauth.expiresAt
     ```

     is in the future.
   - `grep -ac '^-> '` of the file equals the recipient count.

   Traps:
   - Never use `agenix -e` non-interactively, which writes an empty secret.
   - The manifest is JSON; the bootstrap applies it with `kubectl apply -f`,
     which accepts JSON.

4. **`modules/containers/k3d.nix:431-441`: seed selection.**
   - Add a small shell function inside `bootstrapScript`, before the slot
     loop:

     ```bash
     seed_expiry() {
       kubectl apply --dry-run=client -o json -f "$1" 2>/dev/null \
         | jq -r '.data["claude-credentials.json"] // empty' \
         | base64 -d 2>/dev/null \
         | jq -r '.claudeAiOauth.expiresAt // 0' 2>/dev/null || echo 0
     }
     ```

   - In the `else` branch, only when `seed_only=true`: compare
     `seed_expiry "$f"` with `seed_expiry ${snapshotFile}`. If the snapshot
     exists and its expiry is greater, apply the snapshot instead (keep
     `-n factory`) and echo `[k3d-bootstrap] Applied factory/$name from
     snapshot (expires <date>)`.
   - If the chosen expiry is ≤ `$(( $(date +%s) * 1000 ))`, echo the ERROR
     line naming this plan's steps 1-3, then still apply.
   - Define `snapshotFile = "/var/lib/k3d-${cfg.clusterName}/factory-cli-creds.json";`
     in the module `let`, beside `pvSnapshot` (line 80).

   Check: `just check-syntax`; and on a copy of the logic, a snapshot with
   an expired token versus one with a valid token must pick the later
   expiry.
   Traps:
   - In Nix strings, write `''${` for shell `${`.
   - Keep the non-seed-only slots unchanged.

5. **`modules/containers/k3d.nix`, after line 976 (end of the
   `skillai-db-backup` timer): the snapshot unit.**
   `systemd.services.factory-cli-creds-snapshot` (mkIf
   `cfg.argocd.enable`) follows the skillai pattern plus `jq`. Its script:
   - Fetch the live Secret as JSON (`|| { echo "cluster unreachable;
     skipping"; exit 0; }`).
   - Compute the new expiry with the same jq pipeline, and the old one from
     the existing file (or 0).
   - If the new expiry > now and > old, write the same jq projection as
     step 3 to `$snapshotFile.tmp` with `umask 077`, `mv` it into place and
     echo the expiry. Otherwise echo why it skipped.

   `systemd.timers.factory-cli-creds-snapshot`:
   `OnCalendar = "*-*-* 00/4:30:00"; Persistent = true;`.
   Check: `just test-host p620` builds.
   Traps: the file is written only by this unit; never into the Nix store.

6. **Ship.**
   - Commit steps 3-5 together:
     `fix(k3d): seed factory-cli-creds from the freshest copy (#2187)`.
   - Open a PR linking intent, spec and plan, and merge it after CI.
   - Post to the bus, then `nh os switch` p620 from main.

   Check:
   - `systemctl start factory-cli-creds-snapshot` writes the snapshot file
     (`stat -c %a` gives 400, with a future expiry).
   - `systemctl list-timers factory-cli-creds-snapshot` shows the schedule.
   - main's p620 toplevel equals `/run/current-system`.

   Traps:
   - The 04:00 auto-upgrade switches from main, so merge before deploying.
   - #2188 edits the same region of `k3d.nix` and must rebase after this
     merges.

## Tests

- `just check-syntax` and `just test-host p620` pass.
- The step 2 checks pass: broker Job OK, and zero `refusing to adopt` lines
  in 10 min across the three services.
- The step 3 decrypt check passes, with the recipient count unchanged.
- The step 4 selection check passes on a copy.
- The step 6 snapshot check passes.

## Rollback

- **Code.** Revert the PR and switch. The bootstrap goes back to agenix-only
  seeding, and the snapshot unit disappears. Delete the snapshot file with
  `rm /var/lib/k3d-factory/factory-cli-creds.json`.
- **Secret.** `git revert` the `.age` change (the old content is in git).
- **Live Secret.** No rollback needed; the old value was already unusable.
