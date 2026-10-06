---
status: draft
issue: 2187
intent: intent/2026-10-06-2187-factory-cli-creds-stale.md
---

# Spec: factory services get a valid Claude credential, and keep it

## Decisions carried from the intent approval

1. Credential source: **deviation, needs re-approval.** The approved answer
   was the host's `~/.claude/.credentials.json`. That does not work.
   Anthropic rotates the refresh token on every use, and the in-cluster
   `cred-broker` CronJob refreshes every 4 h. If the host and the cluster
   share one token chain, whichever refreshes first invalidates the other.
   The cluster would break the p620 Claude CLI within 4 h, or the CLI would
   break the cluster. This spec uses **a dedicated `claude auth login` for
   the factory**, which has its own token chain.
2. Fix strategy: both. Re-seed now, and make a recreate seed from a fresh
   copy instead of the stale agenix snapshot.
3. Codex, Copilot and Gemini: check them in the same pass. Fix them only if
   they are expired.

## Design

Root cause, confirmed on 2026-10-06:

- `cred-broker` exits with `refresh HTTP 400: invalid_grant`.
- Its access token expired on 2026-08-20, 47 days ago.
- The refresh token in the agenix seed was spent long ago, so the cluster
  cannot recover on its own. The broker says so itself: "a human must
  re-seed the Secret from a fresh `claude auth login`".

### A. Re-seed now (runtime, one-off)

1. The user runs `CLAUDE_CONFIG_DIR=$(mktemp -d) claude auth login` once.
   This is an interactive browser OAuth flow, and the separate config dir
   keeps it out of `~/.claude`. Use the subscription login, never an API key
   (#1831).
2. Patch that `.credentials.json` into the live Secret's
   `claude-credentials.json` key with `kubectl patch`. `cred-sync` sees a
   newer seed through the kubelet volume refresh, so no pod restart is
   needed. Run `cred-broker` once by hand to prove it can refresh.
3. Re-encrypt the agenix slot `secrets/factory-secret-factory-cli-creds.age`
   with that same credential, using `age -R` (never `agenix -e`
   non-interactively, which writes an empty secret). The repo copy is then
   at least valid at the moment of commit. Delete the temporary config dir
   afterwards.

### B. Keep a fresh copy outside git

`modules/containers/k3d.nix` gets a new root oneshot service plus timer,
`factory-cli-creds-snapshot`. It runs every 4 h, offset 30 min after
`cred-broker`, and copies the backup units' pattern (`path`,
`environment.KUBECONFIG`, `after = k3d-cluster-bootstrap`). It:

- Reads the live `factory-cli-creds` Secret.
- Writes it to `/var/lib/k3d-factory/factory-cli-creds.json` (mode 0400,
  root), but only when its Claude `expiresAt` is in the future and later
  than the snapshot already there.
- Lives on the root disk, so it survives a cluster delete. It is a runtime
  file, never in the Nix store.

### C. Seed from the freshest source on recreate

In the seed-only branch of the bootstrap (`k3d.nix` around lines 427-440),
when `factory-cli-creds` is absent:

- Compare the Claude `expiresAt` of the snapshot (B) and the agenix slot,
  and apply whichever is later. The snapshot carries the cluster's latest
  refresh token, which nobody else has spent since the cluster that owned
  it was deleted.
- If the chosen seed is already expired, apply it anyway (Secrets that
  other pods mount must exist), but log a line starting
  `[k3d-bootstrap] ERROR: factory-cli-creds seed expired at <date>` that
  names the section A procedure.

## Alternatives rejected

- **Copy the host's `~/.claude/.credentials.json`.** A shared refresh-token
  chain means the host and the cluster invalidate each other (decision 1).
- **A periodic re-encrypt of the agenix file into the repo.** It dirties
  the tree, so `nhs` refuses to run, and it auto-commits secret material on
  a timer.
- **Loosen `cred-sync` to accept expired seeds.** That regresses
  Factory#628, and an expired token cannot authenticate anyway.
- **Store the snapshot on `/mnt/data`.** It is the QLC disk from #2189, it
  missed a boot this morning, and the snapshot is 20 KB. The root disk is
  fine.

## Risks

- **The login is interactive.** Section A needs the user at a browser once.
  Every later recreate is automatic thanks to B and C.
- **Snapshot exposure.** The snapshot holds live tokens. It is root 0400 on
  `/var/lib`, the same trust level as `/run/agenix`.
- **A snapshot taken mid-refresh.** It is taken 30 min after the broker
  runs and only replaces an older expiry, so a half-written Secret cannot
  win.
- **Codex, Copilot or Gemini entries may also be expired.** These are
  checked in verification. Any refresh for them is a separate follow-up
  unless it is trivial.

## Verification

- `cred-sync` in aifactory, pfactory and tfactory logs adoption, and no
  more refusals for 10 minutes.
- A manual `cred-broker` Job succeeds, and its log shows the new expiry.
- The agenix slot decrypts (`age -d`), its Claude `expiresAt` is in the
  future, and the recipient count is unchanged.
- `factory-cli-creds-snapshot` runs, and the snapshot file exists with mode
  0400 and a future expiry.
- Seed choice: run the bootstrap's selection logic against a snapshot that
  has an expired token and against a valid one, and it must pick the later
  expiry. Test it on a copy, not by deleting the live Secret.
- `just test-host p620` builds.
