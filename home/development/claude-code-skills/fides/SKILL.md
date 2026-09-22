---
name: fides
description: >-
  Operate Fides — the compliance, provenance & evidence-tracking system — from the
  `fides` CLI, the API, and CI/CD pipelines. Use when recording build provenance
  (trails, artifacts, attestations), gating deploys on policy/compliance, running
  the change gate + segregation-of-duties approvals, adopting control frameworks
  (SOC 2, ISO 27001, NIST 800-53, PCI-DSS, DORA, PSD2, SOX, SLSA), verifying
  supply-chain provenance (cosign/Sigstore signatures, SLSA in-toto, SBOM),
  snapshotting runtimes (docker/k8s/ecs/lambda), verifying tamper-evidence chains,
  the continuous control-test timeline, wiring integrations (ServiceNow — including
  consuming ServiceNow's MCP server and grounding Now Assist — Slack, Git providers,
  webhooks), managing service accounts/users, reading DORA metrics, or
  configuring/deploying the Fides server and its MCP server. Triggers on "fides",
  "compliance gate", "attestation", "provenance", "change gate", "SBOM evidence",
  "policy gate", "control coverage", "verify-image", "control timeline",
  "servicenow mcp", "now assist grounding".
---

# Fides — Compliance, Provenance & Evidence Tracking

Fides records and evaluates every state change in the software delivery lifecycle
in real time, acting as an audit-ready single source of truth for frameworks like
SOC 2, ISO 27001, NIST 800-53, PCI-DSS, DORA, PSD2, and SOX. This skill covers the
**`fides` CLI**, its **configuration**, **management/admin** operations, and
**CI/CD pipeline** usage.

## Mental model (read this first)

Provenance flows through a small set of nouns:

- **Flow** — a logical delivery stream (≈ a service/repo). Has a UUID.
- **Trail** — one build/run of a Flow (≈ a Git SHA or build number). Has a UUID.
- **Artifact** — a built deliverable identified by its **SHA256** digest, attached to a trail.
- **Attestation** — a piece of evidence about a trail/artifact (test results, scans,
  SBOM, a ServiceNow change record). Chained per-trail into a tamper-evident hash chain.
- **Environment** — a runtime (docker/k8s/ecs/lambda) you **snapshot**; a **logical-env**
  aggregates several. **Allowlists** and **policies** gate what may run there.
- **Control / Framework** — a compliance control (e.g. `SOC2-CC7.1`) requiring evidence
  types; **enforce** a control to create the environment policy that raises **coverage**.
- **Change gate** — turns evidence + control coverage into an **approve/hold verdict +
  0–100 risk score**, optionally written back to a **ServiceNow** Change Request.
  Fides advises; ServiceNow decides.

The canonical pipeline is: **`trail start` → build → `artifact report` → `attest`
(tests/scans/SBOM) → `assert`/`policy check`/`change-gate` (the gate) → deploy →
`snapshot` (runtime) → `verify-chain`/`audit` (evidence)**.

## Setup / auth (always required)

```bash
export FIDES_SERVER_URL="https://fides.example.com"   # default http://localhost:8080
export FIDES_API_TOKEN="fides_<prefix>_<secret>"      # a service-account key (preferred) or static token
export FIDES_ENCRYPTION_KEY="<passphrase>"            # optional: encrypt attestation payloads (AES-256-GCM)
```

Verify connectivity before doing real work: `fides flow list`.

## Exit codes — the gates (critical for pipelines)

These commands **exit non-zero to fail a CI step** — rely on them, don't parse stdout:

| Command | Non-zero means |
|---|---|
| `fides assert --sha256 <hex> --policy <name>` | exit **1** — artifact non-compliant |
| `fides policy check --env <id> --trail <id>` | exit **2** — an applicable env policy is unsatisfied |
| `fides allowlist check --env <id> --sha <hex>` | exit **2** — digest not approved for the env |
| `fides change-gate --trail <id>` | exit **2** — verdict is HOLD |
| `fides verify-chain --trail <id>` | exit **2** — attestation chain is broken/tampered |

## Common workflows

**Record a build's provenance (in CI).** You *choose* the trail identifier (the Git SHA
is the convention) and pass it consistently — IDs are **not** captured from `fides` stdout:
```bash
TRAIL="$GIT_SHA"                                                    # you set this (build id)
DIGEST=$(docker inspect --format='{{index .Id}}' app:$GIT_SHA)     # or let Fides hash a file with --file
fides trail start     --flow $FLOW_ID --trail "$TRAIL" --repository "$REPO" --commit "$GIT_SHA" --branch "$BRANCH"
fides artifact report --org  $ORG_ID  --trail "$TRAIL" --sha256 "$DIGEST" --name app --type docker
fides attest junit    --trail "$TRAIL" --file reports/junit.xml --artifact-sha "$DIGEST"
fides attest trivy    --trail "$TRAIL" --file reports/trivy.json --artifact-sha "$DIGEST"
fides attest sbom     --artifact-sha "$DIGEST" --file sbom.json                          # --trail optional
```
> `fides attest junit|snyk|trivy|sbom` auto-normalize the report; use generic
> `fides attest --name --type --payload <json|file> [--encrypt]` for anything else.
> `fides attest sbom` auto-detects CycloneDX/SPDX, persists per-component rows
> (purl/name/version/licenses), and powers `fides search components --purl <p>`
> ("which artifacts contain component X").

**Gate a deploy (pick the strictest that applies):**
```bash
fides assert       --sha256 $DIGEST --policy production-release-rules   # policy gate
fides policy check --env $ENV --trail $TRAIL                            # env policy gate
fides change-gate  --trail $TRAIL                                       # verdict + risk (needs SoD approval)
```

**Segregation of duties:** the change gate won't recommend approval without a human
sign-off; four-eyes needs two distinct humans: `fides approve --trail $TRAIL --reason "..."`.

**Adopt & enforce a framework:**
```bash
fides control import --framework SOC2
fides control enforce --all-controls --all-environments
fides control coverage
fides report --framework SOC2          # auditor-ready, control-by-control
```

**Runtime drift check:** `fides snapshot k8s --env $ENV --namespace prod` then
`fides env diff --env $ENV`.

## Reference files (load on demand)

- **`reference/commands.md`** — every command, subcommand, and flag (the complete surface).
- **`reference/configuration.md`** — all environment variables for the CLI *and* the server
  (DB, storage, AI/LLM, secrets, events, RLS/WORM, admission, MCP).
- **`reference/pipelines.md`** — copy-paste GitHub Actions + GitLab CI, the gate-exit-code
  contract, and secret handling.
- **`reference/mcp-and-management.md`** — the `fides-mcp` MCP server (tools + `.mcp.json`),
  WebMCP, and management/admin ops (service accounts, users, integrations, install/seed).

## Rules of thumb

- **Never invent flags.** If unsure, consult `reference/commands.md` — it mirrors the CLI source.
- **Prefer service-account keys** over a static token; rotate by issuing a new key then revoking the old.
- **Use secret references** (`--secret-path`) for integration credentials — never inline secrets.
- **Digests are SHA256**, lowercase hex, no `sha256:` prefix.
- **`fides` reads only `FIDES_SERVER_URL`, `FIDES_API_TOKEN`, `FIDES_ENCRYPTION_KEY`** from the
  environment; everything else configures the *server*, not the CLI.
