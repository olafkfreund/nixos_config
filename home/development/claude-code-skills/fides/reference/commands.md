# Fides CLI — Complete Command Reference

Mirrors `cmd/cli/main.go` + `cmd/cli/integrations.go`. The CLI reads `FIDES_SERVER_URL`
(default `http://localhost:8080`), `FIDES_API_TOKEN`, and optionally
`FIDES_ENCRYPTION_KEY` from the environment. Run `fides help` for the built-in usage.

Top-level commands: `trail`, `artifact`, `attest`, `assert`, `snapshot`, `servicenow`,
`git-provider`, `webhook`, `user`, `verify-chain`, `service-account`, `allowlist`,
`search`, `audit`, `policy`, `logical-env`, `metrics`, `control`, `flow`,
`change-gate`, `report`, `approve`, `slack`, `env`.

---

## Pipeline / build (CI)

### `fides trail start`
Begin a build trail.
```
fides trail start --flow <flow_id> --trail <name> [--repository <url>] [--commit <sha>] [--branch <b>] [--message <m>]
```
- `--flow` (required) Flow UUID · `--trail` (required) trail name (Git SHA / build number)
- `--repository`, `--commit`, `--branch`, `--message` — git metadata (optional)

### `fides artifact report`
Register a build artifact by SHA256 (or compute it from a file).
```
fides artifact report --org <org_id> [--trail <trail_id>] (--sha256 <hex> | --file <path>) --name <name> [--type docker]
```
- `--org` (required) · `--name` (required) · one of `--sha256` / `--file` (required)
- `--trail` trail UUID · `--type` artifact type (default `docker`; e.g. `binary`, `file`)
- `--file` computes the SHA256 locally from the given path.

### `fides attest` (generic evidence)
Report custom evidence for a trail/artifact.
```
fides attest --trail <id> --name <n> --type <t> --payload <json|file.json> [--artifact-sha <hex>] [--attachments a,b] [--encrypt]
```
- Required: `--trail`, `--name`, `--type`, `--payload` (inline JSON string or a `.json` path)
- `--artifact-sha` bind to an artifact · `--attachments` comma-separated files
- `--encrypt` encrypt the payload with `FIDES_ENCRYPTION_KEY` (AES-256-GCM). Encryption is
  also auto-applied if `FIDES_ENCRYPTION_KEY` is set.

### `fides attest junit|snyk|trivy|slsa` (format parsers)
Normalize a raw report into a compliant/non-compliant attestation (original file attached).
```
fides attest junit --trail <id> --file reports/junit.xml [--name <n>] [--artifact-sha <hex>]
fides attest snyk  --trail <id> --file reports/snyk.json  [--name <n>] [--artifact-sha <hex>]
fides attest trivy --trail <id> --file reports/trivy.json [--name <n>] [--artifact-sha <hex>]
fides attest slsa  --trail <id> --file provenance.json    [--name <n>] [--artifact-sha <hex>]
```
- `--file` (required) path to the report · `--name` defaults to the format name
- Normalized payload is `{format, compliant, summary{counts}, findings}` — jq-evaluable
  (e.g. rule `.summary.failed == 0`).
- **SLSA in-toto provenance** records under type `slsa-provenance` (same type as the
  platform-native `fides attest fetch` path), so the SLSA/NIST/SOC2 supply-chain
  controls recognize it.

### `fides attest fetch` / `fides verify-image` (supply-chain provenance)
```
fides attest fetch --trail <id> --artifact-sha <hex> [--provider github|gitlab] [--repo <owner/repo>]
fides verify-image --sha256 <hex> --signer <identity> [--issuer <oidc-issuer>] [--key <pubkey.pem>] [--bundle <path>] [--trail <id>]
```
- `attest fetch` ingests platform-native GitHub/GitLab SLSA attestations → type `slsa-provenance`.
- `verify-image` verifies a cosign/Sigstore signature (keyless OIDC or `--key`), records a
  `cosign-verification` attestation, and **exits 2 on failure** (deploy gate).
- Both feed the `SLSA` framework controls (`slsa-provenance`, `cosign-verification`, `sbom-cyclonedx`).

### `fides attest sbom` (SBOM ingestion)
Auto-detects CycloneDX vs SPDX JSON, normalizes every component (name, version,
purl, licenses), and persists them linked to the artifact — powering
`fides search components`.
```
fides attest sbom --file bom.json --artifact-sha <hex> [--trail <id>] [--name <n>]
```
- `--file` and `--artifact-sha` (required) · `--trail` optional (resolved from the
  artifact's own trail when omitted) · `--name` defaults to `sbom`
- Recorded as an attestation typed `sbom-cyclonedx` (satisfies the SBOM control's
  evidence requirement regardless of the source format).

### `fides assert` — policy gate (**exit 1** on non-compliance)
```
fides assert --sha256 <hex> [--policy <name>]
```
Evaluates the artifact against policy rules via `GET /api/v1/compliance`. Prints violations
and exits non-zero to fail the CI step.

### `fides verify-chain` — tamper-evidence check (**exit 2** if broken)
```
fides verify-chain --trail <id>
```

### `fides audit` — download the trail audit package (ZIP)
```
fides audit --trail <id> [--output <file.zip>]
```
Self-contained ZIP: trail, artifacts, attestations, chain verdict, report.

---

## Runtime snapshots

```
fides snapshot docker --env <id> [--container <name>]
fides snapshot k8s    --env <id> [--namespace <ns>] [--container <name>]   # via kubectl
fides snapshot ecs    --env <id> --cluster <name>                         # via aws CLI
fides snapshot lambda --env <id>                                          # via aws CLI
```
- `--env` (required) environment UUID · `--container` filter one container
- `--namespace` filter pods (k8s; system namespaces are auto-skipped) · `--cluster` required for `ecs`
- k8s uses `kubectl get pods -A -o json`; ecs/lambda shell out to `aws`.

---

## Environments, allowlists & policies

### `fides allowlist` — per-environment artifact approvals
```
fides allowlist add    --env <id> --sha <hex> [--reason <r>]
fides allowlist list   --env <id>
fides allowlist check  --env <id> --sha <hex>     # exit 2 if not approved (deploy gate)
fides allowlist remove --env <id> --sha <hex>
```

### `fides policy` — global policies + environment policies
Global (named) policies:
```
fides policy create   --name <n> --rules-file <rules.json>
fides policy delete   --id <policy_id>
fides policy generate --framework <F> --description "<plain-English goal>"   # AI-drafts rules via the LLM
```
Environment policies (bind required evidence types to an env; optional tag condition):
```
fides policy add   --env <id> --name <n> --require t1,t2 [--if-tag <tag> --if-value <v>]
fides policy list  --env <id>
fides policy check --env <id> --trail <id>        # exit 2 if any applicable policy unsatisfied
```
- `--require` comma-separated attestation types · `--if-tag`/`--if-value` only enforce when a
  flow tag matches.

### `fides logical-env` — aggregate environments
```
fides logical-env create     --name <n> [--description <d>]
fides logical-env list
fides logical-env add-member --id <logical_id> --env <physical_env_id>
fides logical-env state      --id <logical_id>     # unified running services across members
```

### `fides env` — snapshot diff & runtime MCP compliance
```
fides env diff   --env <id> [--from <snap_id>] [--to <snap_id>]      # defaults: 2nd-most-recent → most-recent
fides env verify --env <id> --server <mcp_conn> [--tool get_pods] [--rules-file <rules.txt>]
```
`env verify` runs an in-cluster MCP tool and evaluates one jq rule per line from `--rules-file`.

### `fides flow` — flows, trails, artifacts
```
fides flow list                    # all flows
fides flow trails    --flow <id>   # the flow's build trails (name, commit, compliance)
fides flow artifacts --flow <id>   # artifacts across the flow's trails
```

---

## Controls, frameworks & change gate

```
fides control import   --framework <SOC2|ISO27001|NIST-800-53|PCI-DSS|DORA|PSD2|SOX|SLSA>   # adopt catalog (idempotent)
fides control frameworks                                # list available framework catalogs
fides control list     [--all]                          # controls (--all includes archived)
fides control coverage                                  # evidence + environment coverage per control
fides control timeline [--key <k>] [--days N]           # continuous control-test evidence feed over time (default 90d)
fides control add      --key <k> --name <n> [--description <d>] [--framework <F>] [--require t1,t2]
fides control enforce  --key <k> --env <id>             # create env policy requiring the control's evidence
fides control enforce  --all-controls --all-environments   # raise coverage everywhere (idempotent)
fides control archive   --id <control_id>
fides control unarchive --id <control_id>
```
- `import`/`report` frameworks: `SOC2 | ISO27001 | NIST-800-53 | PCI-DSS | DORA | PSD2 | SOX | SLSA`
  (`SLSA` is the supply-chain integrity catalog: `slsa-provenance`, `cosign-verification`, `sbom-cyclonedx`).
- `control add --framework`: `SOC2 | ISO27001 | FDA-21CFR11` (custom-control tagging).

```
fides report --framework <name>          # auditor-ready, control-by-control (evidence + coverage)
fides change-gate --trail <id>           # approve/hold verdict + 0-100 risk (exit 2 on HOLD)
fides approve --trail <id> [--reason <r>] [--role approver|deployer] # record a segregation-of-duties approval (human vs machine)
```
- Each `change-gate`/`approve` call (re-)records a `segregation-of-duties`
  attestation on the trail, proving committer != approver != deployer (identity
  sources: the trail's `--committer` tag from `fides trail start`, and the
  `--role approver|deployer` approvals above). `compliant: true` only when all
  three identities are pairwise-distinct — required by PCI-DSS 4.0 / SOX ITGC.

---

## Search & metrics

```
fides search artifacts    [--sha <prefix>] [--commit <sha>] [--name <substr>]
fides search attestations [--type <t>] [--trail <id>] [--compliant true|false]
fides search components   [--purl <p>] [--artifact <sha>] [--name <substr>]  # which artifacts contain component X
fides metrics                      [--days N]     # DORA delivery metrics (default 30d)
fides metrics deployment-frequency [--weeks N]    # weekly per-environment (default 12w)
```

---

## Integrations & admin config

### `fides servicenow`
```
fides servicenow config --instance-url https://<inst>.service-now.com --auth-type <basic|oauth2> \
    --client-id <id-or-username> --secret-path <ref> [--disable]
fides servicenow get                              # show current config
fides servicenow change-check --trail <id> (--change CHG0030192 | --ci <cmdb_ci_name>)
fides servicenow link-control --trail <id> --change CHG0030192 --control <key> [--attestation <id>]
fides servicenow anchor-deployment --trail <id> (--change CHG0030192 | --ci <name>) [--build-log <url>]
fides servicenow grounding --change CHG0030192    # Now Assist grounding pack (coverage+evidence+risk+NL summary)
# Consume ServiceNow's own MCP server (Fides is the MCP client):
fides servicenow mcp servers                       # discover provisioned SN MCP servers (sn_mcp_server_registry)
fides servicenow mcp lookup --table <t> [--query <q>] [--limit N]   # governed record lookup (CMDB/change/GRC)
fides servicenow mcp tools  [--server <name>]      # list a GA MCP server's tools
fides servicenow mcp call   --tool <t> [--server <name>] [--args '<json>']
```
See `docs/servicenow-mcp.md` (Fides→SN) and `docs/servicenow-now-assist-grounding.md` (SN→Fides).

### `fides git-provider`
```
fides git-provider config --provider <github|gitlab|bitbucket|azure-devops> --host <h> \
    --api-base <url> --token-path <ref> [--inbound-secret-path <ref>] [--disable]
```
Enables commit-status checks and signed inbound push webhooks.

### `fides webhook`
```
fides webhook config --name <n> --url <https-url> --secret-path <ref> [--events e1,e2] [--disable]
```
`--events` empty = all. Payloads are HMAC-signed with the referenced secret.

### `fides slack`
```
fides slack config --secret-path <ref> [--disable]   # ref -> Slack incoming-webhook URL
```
Posts `compliance.evaluated` / `snapshot.noncompliant` when the event engine is on
(`FIDES_EVENTS_ENABLED=true`).

### `fides service-account` — accounts + rotatable API keys
```
fides service-account create     --name <n> [--role Admin|Auditor|Writer|Viewer]   # default Writer
fides service-account list
fides service-account issue-key  --account <sa_id> [--label <l>] [--expires-hours <n>]  # prints key ONCE
fides service-account revoke-key --account <sa_id> --key <key_id>
```
Issued key format: `fides_<prefix>_<secret>`. Rotate = issue new → switch CI → revoke old.

### `fides user`
```
fides user set-password --user <id> --password '<min-8-chars>'
```

---

## Global conventions

- **UUIDs** for flow/trail/artifact/env/control/service-account/user IDs.
- **SHA256** digests: lowercase hex, no `sha256:` prefix.
- **`--secret-path`** takes a *reference* (an env-var name or a Secrets Manager id), not a raw secret.
- Gate commands signal via **exit code**, not stdout — see the exit-code table in `SKILL.md`.
