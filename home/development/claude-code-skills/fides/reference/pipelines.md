# Fides in CI/CD Pipelines

The canonical provenance-and-gate flow for any build/deploy pipeline:

```
trail start → build → artifact report → attest (tests/scans/SBOM) → GATE → deploy → snapshot → verify-chain/audit
```

The **GATE** is one or more of `assert`, `policy check`, or `change-gate` — each exits
non-zero to fail the step (see the exit-code contract below). Never parse stdout to
decide pass/fail; rely on the exit code.

## Secrets in CI

Provide a **Writer** service-account key (not a personal token):
```bash
export FIDES_SERVER_URL="https://fides.example.com"
export FIDES_API_TOKEN="$FIDES_CI_KEY"          # from the CI secret store
export FIDES_ENCRYPTION_KEY="$FIDES_ENC_KEY"    # only if encrypting payloads
```
Create/rotate the key with `fides service-account issue-key --account <sa> --label ci --expires-hours 720`.

## Gate exit-code contract

| Gate | Fails the step (non-zero) when |
|---|---|
| `fides assert --sha256 $DIGEST --policy <name>` | artifact violates policy (**exit 1**) |
| `fides policy check --env $ENV --trail $TRAIL` | an applicable environment policy is unsatisfied (**exit 2**) |
| `fides allowlist check --env $ENV --sha $DIGEST` | digest not approved for the environment (**exit 2**) |
| `fides change-gate --trail $TRAIL` | verdict is HOLD (**exit 2**) |
| `fides verify-chain --trail $TRAIL` | attestation chain broken/tampered (**exit 2**) |
| `fides verify-image --sha256 $DIGEST --signer <id> --issuer <oidc>` | cosign/Sigstore signature invalid (**exit 2**) |

## GitHub Actions

`TRAIL_ID` is a value **you set** (the Git SHA by convention) and pass to every `--trail`;
`DIGEST` comes from `docker inspect`. Don't capture IDs from `fides` stdout.

```yaml
name: build-and-attest
on: { push: { branches: [main] } }
env:
  FIDES_SERVER_URL: https://fides.example.com
  FIDES_API_TOKEN: ${{ secrets.FIDES_CI_KEY }}
  FIDES_ENCRYPTION_KEY: ${{ secrets.FIDES_ENC_KEY }}   # only if encrypting payloads
  ORG_ID:   ${{ vars.FIDES_ORG_ID }}
  FLOW_ID:  ${{ vars.FIDES_FLOW_ID }}
  ENV_ID:   ${{ vars.FIDES_PROD_ENV_ID }}
  TRAIL_ID: ${{ github.sha }}
jobs:
  ship:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Fides CLI
        run: curl -sSfL $FIDES_SERVER_URL/cli/install.sh | sh

      - name: Start trail
        run: |
          fides trail start --flow $FLOW_ID --trail $TRAIL_ID \
            --repository "${{ github.repository }}" --commit "${{ github.sha }}" \
            --branch "${{ github.ref_name }}" --message "${{ github.event.head_commit.message }}"

      - name: Build + test + scan
        run: |
          docker build -t app:${{ github.sha }} .
          echo "DIGEST=$(docker inspect --format='{{index .Id}}' app:${{ github.sha }})" >> $GITHUB_ENV
          # ... run tests/scanners producing reports/junit.xml, reports/trivy.json ...

      - name: Report artifact + attest evidence
        run: |
          fides artifact report --org $ORG_ID --trail $TRAIL_ID --sha256 $DIGEST --name app --type docker
          fides attest junit --trail $TRAIL_ID --file reports/junit.xml --artifact-sha $DIGEST
          fides attest trivy --trail $TRAIL_ID --file reports/trivy.json --artifact-sha $DIGEST

      - name: Compliance gate         # fails the job on non-compliance / HOLD
        run: |
          fides assert      --sha256 $DIGEST --policy production-release-rules
          fides change-gate --trail $TRAIL_ID

      - name: Deploy
        run: ./deploy.sh app:${{ github.sha }}

      - name: Record runtime + verify
        run: |
          fides snapshot k8s --env $ENV_ID --namespace prod
          fides verify-chain --trail $TRAIL_ID
```

## GitLab CI

```yaml
stages: [build, gate, deploy, verify]
variables:
  FIDES_SERVER_URL: "https://fides.example.com"
  TRAIL_ID: "$CI_COMMIT_SHA"
  # FIDES_API_TOKEN, ORG_ID, FLOW_ID, ENV_ID set as (masked) CI/CD variables

build:
  stage: build
  script:
    - curl -sSfL $FIDES_SERVER_URL/cli/install.sh | sh
    - fides trail start --flow $FLOW_ID --trail $TRAIL_ID
        --repository $CI_PROJECT_URL --commit $CI_COMMIT_SHA --branch $CI_COMMIT_REF_NAME
    - docker build -t app:$CI_COMMIT_SHA .
    - DIGEST=$(docker inspect --format='{{index .Id}}' app:$CI_COMMIT_SHA)
    - echo "DIGEST=$DIGEST" > dig.env
    - fides artifact report --org $ORG_ID --trail $TRAIL_ID --sha256 $DIGEST --name app --type docker
    - fides attest junit --trail $TRAIL_ID --file reports/junit.xml --artifact-sha $DIGEST
    - fides attest trivy --trail $TRAIL_ID --file reports/trivy.json --artifact-sha $DIGEST
  artifacts: { reports: { dotenv: dig.env } }

gate:
  stage: gate
  script:
    - fides assert --sha256 $DIGEST --policy production-release-rules
    - fides policy check --env $ENV_ID --trail $TRAIL_ID
    - fides change-gate --trail $TRAIL_ID       # exit 2 => job fails => deploy blocked

deploy:
  stage: deploy
  script: ["./deploy.sh app:$CI_COMMIT_SHA"]

verify:
  stage: verify
  script:
    - fides snapshot k8s --env $ENV_ID --namespace prod
    - fides verify-chain --trail $TRAIL_ID
```

## Patterns & tips

- **Conditional evidence via flow tags:** require a change record only for high-risk flows —
  tag the flow (`POST /api/v1/flows/$FLOW/tags {"tags":{"risk":"high"}}`), then
  `fides policy add --env $ENV --name high-risk --require servicenow-change --if-tag risk --if-value high`.
- **Deploy allow-list gate:** `fides allowlist add --env $ENV --sha $DIGEST --reason "release board"`
  before deploy, `fides allowlist check --env $ENV --sha $DIGEST` in the deploy job.
- **Segregation of duties:** `change-gate` holds until a human `fides approve --trail $TRAIL`
  (four-eyes = two distinct humans). Model the approval as a manual pipeline step.
- **ServiceNow write-back:** `fides servicenow change-check --trail $TRAIL --change CHG...` (or the
  API `POST /api/v1/servicenow/change-gate`) writes the verdict + risk onto the Change Request.
- **Auditor artifact:** publish `fides audit --trail $TRAIL --output trail-audit.zip` as a build artifact.
- **Runtimes beyond k8s:** `fides snapshot docker|ecs --cluster <c>|lambda --env $ENV`.
