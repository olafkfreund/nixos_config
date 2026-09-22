---
name: backstage-patterns
description: "Backstage patterns: Software Catalog (catalog-info.yaml, kinds, relations, lifecycle), TechDocs (MkDocs, techdocs-cli), Scaffolder templates (CSF3, steps, fetch:template, publish:github), custom plugins (frontend React, backend Express), GitHub App integration, and Chromatic CI."
---

# Backstage Patterns

Reference for building and customizing Backstage — the open-source Internal Developer Portal from Spotify.

## When to Activate

- Creating or updating `catalog-info.yaml` for a service
- Writing Backstage Scaffolder templates (Golden Paths)
- Building a custom Backstage plugin
- Setting up TechDocs for a service
- Configuring GitHub App integration
- Designing the software catalog entity model
- Onboarding a new microservice into an existing Internal Developer Portal with team ownership and dependency tracking
- Implementing a self-service workflow so developers can provision new services, databases, or queues through the Scaffolder UI
- Migrating documentation from a wiki to TechDocs so it stays co-located with the code that it describes

---

## Software Catalog

### catalog-info.yaml — All Kinds

```yaml
# Component — a deployable service, library, or website
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payment-service
  description: Processes payments via Stripe
  annotations:
    backstage.io/techdocs-ref: dir:.   # TechDocs from ./docs/
    github.com/project-slug: myorg/payment-service
    pagerduty.com/integration-key: abc123def456
  labels:
    tier: critical
  tags: [typescript, stripe, postgres]
spec:
  type: service          # service | library | website | documentation
  lifecycle: production  # experimental | production | deprecated
  owner: group:payments-team
  system: ecommerce
  dependsOn:
    - resource:payments-db
    - resource:stripe-integration
  providesApis: [payment-api]
  consumesApis: [order-api]

---
# API — an interface provided or consumed by components
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: payment-api
spec:
  type: openapi         # openapi | asyncapi | graphql | grpc
  lifecycle: production
  owner: group:payments-team
  definition: |
    openapi: 3.0.0
    info:
      title: Payment API
      version: v1
    paths:
      /payments:
        post:
          summary: Create payment

---
# Resource — infrastructure (DB, queue, storage)
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: payments-db
  description: PostgreSQL for payment records
spec:
  type: database        # database | s3-bucket | message-queue | cache
  owner: group:platform-team
  system: ecommerce

---
# System — collection of related components/resources
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: ecommerce
  description: The e-commerce platform
spec:
  owner: group:platform-team
  domain: commerce

---
# Group — a team or org unit
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: payments-team
spec:
  type: team
  children: []
  members: [user:alice, user:bob]
  parent: group:engineering
```

### Relations Reference

| Relation | Direction | Example |
|----------|-----------|---------|
| `dependsOn` | Component → Resource/Component | service depends on database |
| `providesApis` | Component → API | service exposes this API |
| `consumesApis` | Component → API | service calls this API |
| `ownedBy` | Any → Group | team owns this service |
| `partOf` | Component → System | service is part of system |
| `hasMember` | Group → User | user is on this team |

### Auto-Discovery

```yaml
# app-config.yaml — discover all catalog-info.yaml in GitHub org
catalog:
  providers:
    github:
      myorg:
        organization: 'myorg'
        catalogPath: '/catalog-info.yaml'
        filters:
          branch: 'main'
          repository: '.*'  # regex — all repos
        schedule:
          frequency: { minutes: 30 }
          timeout: { minutes: 3 }
```

### Entity Lifecycle Management

```yaml
# Mark deprecated — still tracked, shows warning in portal
metadata:
  annotations:
    backstage.io/orphan: 'true'  # Not owned, needs cleanup
spec:
  lifecycle: deprecated
```

---

## TechDocs

Documentation co-located with code, rendered in Backstage.

```
my-service/
  catalog-info.yaml         # Points to TechDocs
  mkdocs.yml               # MkDocs configuration
  docs/
    index.md               # Required — root page
    architecture.md
    runbook.md
    api-reference.md
```

```yaml
# mkdocs.yml
site_name: Payment Service
site_description: Handles payments via Stripe
docs_dir: docs

nav:
  - Home: index.md
  - Architecture: architecture.md
  - Runbook: runbook.md
  - API: api-reference.md

plugins:
  - techdocs-core  # Required Backstage plugin
```

```yaml
# catalog-info.yaml annotation
metadata:
  annotations:
    backstage.io/techdocs-ref: dir:.  # docs/ in same directory
    # Or: url:https://github.com/myorg/docs-repo/tree/main/payment-service
```

```bash
# Local preview
npx @techdocs/cli serve

# Build (for CI)
npx @techdocs/cli build

# Publish to S3 (TechDocs publisher)
npx @techdocs/cli publish --publisher-type awsS3 \
  --storage-name my-techdocs-bucket \
  --entity default/component/payment-service
```

---

## Scaffolder Templates (Golden Paths)

### Template Anatomy

```yaml
# templates/nodejs-api/template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: nodejs-rest-api
  title: Node.js REST API
  description: Production-ready Node.js API with Docker, CI/CD, and observability
  tags: [nodejs, typescript, rest-api]
spec:
  owner: group:platform-team
  type: service

  parameters:
    - title: Service Details
      required: [name, description, owner]
      properties:
        name:
          type: string
          pattern: '^[a-z][a-z0-9-]*[a-z0-9]$'
          description: Lowercase, hyphens OK (e.g., order-processor)
        description:
          type: string
          description: What does this service do?
        owner:
          type: string
          ui:field: OwnerPicker    # Entity picker UI component
          ui:options:
            allowedKinds: [Group]

    - title: Infrastructure
      properties:
        database:
          type: boolean
          default: false
          description: Provision a PostgreSQL database?
        queue:
          type: boolean
          default: false
          description: Provision an SQS queue?

    - title: Repository
      required: [repoUrl]
      properties:
        repoUrl:
          type: string
          ui:field: RepoUrlPicker    # Repository picker
          ui:options:
            allowedHosts: [github.com]

  steps:
    - id: fetch-template
      name: Fetch Template
      action: fetch:template
      input:
        url: ./skeleton         # Template files directory
        values:
          name: ${{ parameters.name }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          destination: ${{ parameters.repoUrl | parseRepoUrl }}

    - id: publish-github
      name: Create GitHub Repository
      action: publish:github
      input:
        repoUrl: ${{ parameters.repoUrl }}
        description: ${{ parameters.description }}
        defaultBranch: main
        gitCommitMessage: 'chore: initialize from golden path'

    - id: register-catalog
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish-github'].output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

    - id: provision-db
      name: Provision Database
      if: ${{ parameters.database }}
      action: github:actions:dispatch
      input:
        repoUrl: github.com?repo=infra&owner=myorg
        workflowId: provision-db.yml
        branchOrTagName: main
        workflowInputs:
          service_name: ${{ parameters.name }}

  output:
    links:
      - title: Repository
        url: ${{ steps['publish-github'].output.remoteUrl }}
      - title: Open in Backstage
        icon: catalog
        entityRef: ${{ steps['register-catalog'].output.entityRef }}
```

### Template Skeleton Files

```
templates/nodejs-api/skeleton/
  .github/workflows/
    ci.yml                # ${{ values.name }} — templated
  src/
    index.ts
    app.ts
  Dockerfile
  catalog-info.yaml       # Pre-filled with service metadata
  package.json
  README.md
```

```yaml
# skeleton/catalog-info.yaml — will be templated
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.name }}
  description: ${{ values.description }}
spec:
  type: service
  lifecycle: experimental
  owner: ${{ values.owner }}
```

---

## Custom Plugins

### Frontend Plugin

```typescript
// plugins/my-plugin/src/plugin.ts
import { createPlugin, createRoutableExtension } from '@backstage/core-plugin-api';
import { rootRouteRef } from './routes';

export const myPlugin = createPlugin({
  id: 'my-plugin',
  routes: {
    root: rootRouteRef,
  },
});

export const MyPluginPage = myPlugin.provide(
  createRoutableExtension({
    name: 'MyPluginPage',
    component: () => import('./components/MyPluginPage').then(m => m.MyPluginPage),
    mountPoint: rootRouteRef,
  }),
);
```

```typescript
// plugins/my-plugin/src/components/MyPluginPage.tsx
import React from 'react';
import { useEntity } from '@backstage/plugin-catalog-react';
import { InfoCard, Progress } from '@backstage/core-components';
import { useApi } from '@backstage/core-plugin-api';

export const MyPluginPage = () => {
  const { entity } = useEntity();
  const [data, setData] = React.useState(null);

  React.useEffect(() => {
    // Fetch plugin-specific data for this entity
    fetchData(entity.metadata.name).then(setData);
  }, [entity]);

  if (!data) return <Progress />;

  return (
    <InfoCard title="My Plugin">
      <pre>{JSON.stringify(data, null, 2)}</pre>
    </InfoCard>
  );
};
```

### Backend Plugin

```typescript
// plugins/my-plugin-backend/src/router.ts
import { Router } from 'express';
import { PluginEnvironment } from '../types';

export async function createRouter(env: PluginEnvironment): Promise<Router> {
  const router = Router();

  router.get('/health', (_, res) => res.json({ status: 'ok' }));

  router.get('/entity/:name', async (req, res) => {
    const { name } = req.params;

    // Access catalog from backend
    const entities = await env.catalog.getEntities({
      filter: [{ 'metadata.name': name }],
    });

    res.json(entities.items[0] ?? null);
  });

  return router;
}
```

---

## GitHub App Integration

```yaml
# app-config.yaml
integrations:
  github:
    - host: github.com
      apps:
        - appId: 12345
          webhookUrl: https://backstage.mycompany.com/api/events/http/github-app-webhook
          clientId: Iv1.abc123
          clientSecret: ${GITHUB_APP_CLIENT_SECRET}
          privateKey: ${GITHUB_APP_PRIVATE_KEY}
          webhookSecret: ${GITHUB_APP_WEBHOOK_SECRET}

auth:
  providers:
    github:
      development:
        clientId: ${GITHUB_AUTH_CLIENT_ID}
        clientSecret: ${GITHUB_AUTH_CLIENT_SECRET}
```

```bash
# Create GitHub App via Backstage CLI
npx @backstage/create-github-app myorg

# Permissions needed:
# - Contents: Read
# - Pull requests: Read & Write (for Scaffolder)
# - Actions: Read & Write (for triggering workflows)
# - Members: Read (for team mapping)
```

---

## Production Configuration

```yaml
# app-config.production.yaml
app:
  baseUrl: https://backstage.mycompany.com

backend:
  baseUrl: https://backstage.mycompany.com
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: backstage

techdocs:
  builder: external  # Build in CI, not in Backstage
  publisher:
    type: awsS3
    awsS3:
      bucketName: my-techdocs-bucket
      region: us-east-1
      accountId: '123456789'
```

## Reference

- `platform-engineering` — IDP strategy, maturity model, Team Topologies
- `visual-testing` — Chromatic integration for Storybook-based component libraries
