# PLAN: Env Pinger — Azure Logic Apps CI/CD Demo

## Goal

Demonstrate CI/CD and Infrastructure-as-Code for Azure Logic Apps across 3 environments
(dev, uat, prod) using **Bicep** and **GitHub Actions**, authenticated via an
**Azure Service Principal**.

The Logic App itself is intentionally trivial — an HTTP-triggered workflow that returns
a JSON response identifying which environment it's running in. The point is the pipeline,
not the app.

---

## The Logic App

- **Type:** Consumption (simplest, no App Service Plan needed)
- **Trigger:** HTTP Request (When a HTTP request is received)
- **Action:** Response — returns JSON:
  ```json
  {
    "message": "Hi from <environment>",
    "resource_group": "rg-envpinger-<environment>",
    "timestamp": "@{utcNow()}"
  }
  ```
- **Parameterization:** The environment name is a Bicep parameter. One template,
  three parameter files. Resource names, tags, and the response body all derive
  from the environment parameter.

---

## Infrastructure (Bicep)

### Resources per environment

| Resource                | Naming Pattern            |
|-------------------------|---------------------------|
| Resource Group          | `rg-envpinger-<env>`      |
| Logic App (Consumption) | `logic-envpinger-<env>`   |

### Why Bicep over Terraform

- **First-party** — ships with Azure CLI, nothing extra to install
- **No state file** — Azure is the source of truth, no remote backend to manage
- **No bootstrap infrastructure** — no Storage Account for state, no init step
- **Cross-platform** — Azure CLI runs on Windows, Mac, Linux

### File structure

```
infra/
├── main.bicep               # Logic App definition (resource group-scoped)
├── environments/
│   ├── dev.bicepparam        # environment = 'dev'
│   ├── uat.bicepparam        # environment = 'uat'
│   └── prod.bicepparam       # environment = 'prod'
```

### Parameterization approach

- `main.bicep` declares parameters: `environment` (string) and `location` (string, default `eastus`)
- Each `environments/<env>.bicepparam` sets `environment = '<env>'`
- All resource names, tags, and the Logic App response body use the `environment` parameter
- Resource group is created via `az group create` (one-liner) before deployment

### Deployment commands

```
az group create --name rg-envpinger-<env> --location eastus
az deployment group create \
  --resource-group rg-envpinger-<env> \
  --template-file infra/main.bicep \
  --parameters infra/environments/<env>.bicepparam
```

### Validation commands

```
az bicep build --file infra/main.bicep                    # syntax check
az deployment group what-if \                              # preview changes (like terraform plan)
  --resource-group rg-envpinger-<env> \
  --template-file infra/main.bicep \
  --parameters infra/environments/<env>.bicepparam
```

---

## Authentication — Azure Service Principal

### Setup (one-time, manual)

A single Service Principal with Contributor role scoped to the subscription:

```
az ad sp create-for-rbac \
  --name sp-envpinger \
  --role Contributor \
  --scopes /subscriptions/<subscription-id> \
  --json-auth
```

Store the JSON output as a single GitHub Actions secret:

| Secret | Value |
|--------|-------|
| `AZURE_CREDENTIALS` | JSON output from the command above |

The JSON object:
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "..."
}
```

Used by the `azure/login@v2` GitHub Action.

---

## CI/CD — GitHub Actions

### Workflow files

```
.github/workflows/
├── pr-validate.yml      # Runs on PRs
├── deploy-dev.yml       # Runs on merge to main
├── deploy-uat.yml       # Manual trigger (workflow_dispatch)
└── deploy-prod.yml      # Manual trigger + environment protection (approval gate)
```

### Pipeline flow

```
PR opened/updated
  └─► pr-validate.yml
        ├── az bicep build (syntax validation)
        └── az deployment group what-if (preview against dev)

Merge to main
  └─► deploy-dev.yml
        ├── az group create (idempotent)
        └── az deployment group create (dev)

Manual trigger
  └─► deploy-uat.yml
        ├── az group create (idempotent)
        └── az deployment group create (uat)

Manual trigger + approval gate
  └─► deploy-prod.yml
        ├── az group create (idempotent)
        └── az deployment group create (prod)
```

### GitHub Environments

Configure these in the repo settings (manual, one-time):

| Environment | Protection Rules            |
|-------------|-----------------------------|
| `dev`       | None                        |
| `uat`       | None (manual trigger only)  |
| `prod`      | Required reviewers (1+)     |

---

## Project Structure

```
├── infra/
│   ├── main.bicep               # Logic App definition
│   └── environments/
│       ├── dev.bicepparam       # Parameters for dev
│       ├── uat.bicepparam       # Parameters for uat
│       └── prod.bicepparam      # Parameters for prod
├── .github/
│   └── workflows/
│       ├── pr-validate.yml      # PR: build, what-if
│       ├── deploy-dev.yml       # Auto-deploy on merge to main
│       ├── deploy-uat.yml       # Manual trigger
│       └── deploy-prod.yml      # Manual trigger + approval
├── .gitignore
├── PLAN.md
└── README.md
```

---

## Implementation Steps

### Phase 0 — Prerequisites (manual, one-time)

- [ ] Azure subscription with permissions to create resources
- [ ] Azure CLI installed locally (includes Bicep)
- [ ] Create Service Principal: `az ad sp create-for-rbac ...`
- [ ] Add `AZURE_CREDENTIALS` as a GitHub repo secret
- [ ] Configure GitHub Environments (`dev`, `uat`, `prod`) with protection rules

### Phase 1 — Bicep

- [ ] Write `infra/main.bicep` (Logic App with parameterized HTTP response)
- [ ] Write `infra/environments/dev.bicepparam`
- [ ] Write `infra/environments/uat.bicepparam`
- [ ] Write `infra/environments/prod.bicepparam`
- [ ] Test locally: validate, what-if, deploy to dev

### Phase 2 — GitHub Actions

- [ ] Write `pr-validate.yml`
- [ ] Write `deploy-dev.yml`
- [ ] Write `deploy-uat.yml`
- [ ] Write `deploy-prod.yml`
- [ ] Push to a branch, open a PR, verify pr-validate runs
- [ ] Merge, verify dev deploys
- [ ] Manually trigger uat and prod deploys

### Phase 3 — Verify

- [ ] `curl` the dev Logic App URL → see "Hi from dev"
- [ ] `curl` the uat Logic App URL → see "Hi from uat"
- [ ] `curl` the prod Logic App URL → see "Hi from prod"
- [ ] Make a change (e.g., update the message), push through the pipeline, verify it propagates

---

## Out of scope (for this demo)

- Networking / VNETs / private endpoints
- Monitoring / alerting
- Logic App Standard (App Service Plan based)
- Separate repos or monorepo patterns
- Branch-per-environment strategy (we use main + manual promotion)
- Multiple Service Principals per environment (production would scope tighter)
