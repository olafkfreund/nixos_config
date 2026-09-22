# Fides — MCP Server, WebMCP & Management/Admin

## The Fides MCP server (`fides-mcp`)

`fides-mcp` is a Model Context Protocol server so AI tools (Claude Code, Cursor,
Claude Desktop) can query compliance data **and read the Fides docs** in-conversation.
It ships in the container image at `/usr/local/bin/fides-mcp`.

**Register it (`.mcp.json`):**
```jsonc
{ "mcpServers": { "fides": {
  "command": "/usr/local/bin/fides-mcp",
  "env": {
    "FIDES_SERVER_URL": "https://fides.example.com",
    "FIDES_API_TOKEN": "<service-account key>"
  }
} } }
```

**Tools** — read + record provenance:
- `list_flows`, `list_environments`, `list_policies`
- `check_compliance` — evaluate rules against an artifact SHA256
- `search_artifacts`, `search_attestations`
- `get_controls_coverage` — control coverage across frameworks
- `get_deployment_frequency` — DORA deployment-frequency metrics
- `ground_change` — Now Assist grounding pack for a change number (control-coverage +
  evidence + change-gate risk + a natural-language `grounding_summary` to quote)
- ServiceNow tools (change-gate write-back) + provenance-recording tools (trail/artifact/attest)

**Resources:** the documentation is exposed as MCP resources under `fides://docs/*`.

### Fides ⇄ ServiceNow over MCP
- **Fides → SN (MCP client):** Fides consumes ServiceNow's native MCP server to read CMDB
  CIs, change requests, and GRC controls *through SN's governance* — `fides servicenow mcp
  servers|lookup|tools|call`, or the API `/api/v1/servicenow/mcp/*`. GA endpoint is
  `<instance>/sncapps/mcp-server/mcp/<server>` (Streamable HTTP, OAuth); governed lookup is
  `/api/sn_mcp_server/mcp_lookup_service/get_records`. See `docs/servicenow-mcp.md`.
- **SN → Fides (grounding):** ServiceNow's Now Assist is grounded on Fides evidence via
  `GET /api/v1/servicenow/grounding?change=CHGxxxx` (or the `ground_change` MCP tool /
  `fides servicenow grounding`). See `docs/servicenow-now-assist-grounding.md`.
- "Fides advises; ServiceNow decides."

Full guide: `docs/mcp-server.md`.

### In-browser WebMCP

The portal registers Fides tools with the browser via the W3C `document.modelContext`
API (with the `@mcp-b/global` polyfill fallback), so browser agents / local LLMs can act
inside the auditor's authenticated session. Exposed (read-only unless noted):
`fides_list_flows`, `fides_list_environments`, `fides_list_policies`,
`fides_controls_coverage`, `fides_search_artifacts`, `fides_search_attestations`,
`fides_deployment_frequency`, `fides_compliance_summary`, plus the safe actions
`fides_enforce_control` and `fides_import_framework`.

### Runtime MCP compliance (in-cluster sensor)

`cmd/mcp-sensor` is a stdio sensor for environment runtime checks. `fides env verify
--env <id> --server <conn> --tool get_pods --rules-file rules.txt` runs an MCP tool and
evaluates one jq rule per line. Sensor commands are constrained by
`FIDES_MCP_ALLOWED_COMMANDS`.

---

## Management / admin operations

### Identity & access
```bash
# service accounts + rotatable API keys (prefer these over a static token)
fides service-account create     --name ci-pipeline --role Writer      # Admin|Auditor|Writer|Viewer
fides service-account issue-key  --account $SA --label github-actions --expires-hours 720   # prints key ONCE
fides service-account list
fides service-account revoke-key --account $SA --key $OLD_KEY_ID        # rotation: issue new, switch, revoke old

# local user password
fides user set-password --user $USER_ID --password 'S0me-Strong-Pass'
```
Roles: **Admin** (full), **Writer** (record provenance/CI), **Auditor** (read + reports),
**Viewer** (read-only). SSO group→role mappings are managed in the portal Settings page.

### Integration connections (credentials via `--secret-path` references)
```bash
fides servicenow config --instance-url https://acme.service-now.com --auth-type basic \
    --client-id svc-fides --secret-path fides/servicenow
fides git-provider config --provider github --host github.com \
    --api-base https://api.github.com --token-path fides/gh-token --inbound-secret-path fides/gh-webhook
fides webhook config --name audit-sink --url https://example.com/hook --secret-path fides/hook-secret
fides slack config --secret-path fides/slack-webhook
```
`--secret-path` is a *reference* resolved by `SECRETS_PROVIDER` (env var, or AWS Secrets
Manager id when `SECRETS_PROVIDER=aws`). Sinks fire only when `FIDES_EVENTS_ENABLED=true`.

### Frameworks, controls & governance
```bash
fides control import   --framework SOC2                  # adopt catalog (idempotent)
fides control frameworks                                 # list catalogs
fides control coverage                                   # per-control evidence + env coverage
fides control enforce  --all-controls --all-environments # create env policies -> raise coverage
fides control add      --key ACME-1 --name "Custom" --require junit,trivy
fides control archive/unarchive --id <control_id>
fides report --framework SOC2                            # auditor-ready report
fides change-gate --trail $TRAIL                         # verdict + 0-100 risk (exit 2 on HOLD)
fides approve     --trail $TRAIL --reason "platform lead review"   # SoD approval
```
Frameworks (`import`/`report`): `SOC2, ISO27001, NIST-800-53, PCI-DSS, DORA, PSD2, SOX`.

### Metrics & monitoring
```bash
fides metrics --days 30                        # DORA: deployments, frequency, compliance & change-failure rate
fides metrics deployment-frequency --weeks 12  # weekly per environment
```
Server exposes Prometheus/OpenTelemetry at `/metrics`. Admin pages: `/servicenow`, `/admin`.

---

## Install & seed

```bash
# Helm (server + one-step seed job)
helm install fides ./charts/fides -n fides --create-namespace \
  --set database.host=<pg-host> --set database.ownerPassword=<pw> \
  --set database.appPassword=<pw> --set org.id=$(uuidgen) \
  --set portal.username=admin --set portal.password=<pw>

# Or seed an existing Postgres
ORG_NAME="Acme Corp" ./scripts/setup-db.sh
```
The server applies embedded migrations on boot when `FIDES_AUTO_MIGRATE=true`. Full
walkthrough (RLS role, secrets, first login, upgrades): `docs/setup.md`.

---

## Where to look in the repo

- CLI: `cmd/cli/` · MCP server: `cmd/mcp/` · sensor: `cmd/mcp-sensor/` · server: `cmd/server` + `pkg/api`
- Integrations: `pkg/servicenow`, `pkg/slack`, `pkg/gitstatus`, `pkg/webhooks`, `pkg/inbound`, `pkg/admission`
- Secrets: `pkg/vault` · events/outbox: `pkg/events` · migrations: `pkg/db/migrations/*.sql`
- Docs: `docs/cli-reference.md`, `docs/features.md`, `docs/servicenow-integration.md`,
  `docs/mcp-server.md`, `docs/environment-mcp-compliance.md`, `docs/aws-secrets-manager.md`, `docs/setup.md`
