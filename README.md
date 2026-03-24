# env-pinger-logic-apps-azure

CI/CD and IaC demo for Azure Logic Apps using GitHub Actions & Bicep.

Deploys a simple HTTP-triggered Logic App across 3 environments (dev, uat, prod).
Hit the endpoint, get back `"Hi from <environment>"` — proving the pipeline and
parameterization work end-to-end.

## Architecture

```
GitHub Actions (CI/CD)
  │
  ├── PR → validate (bicep build, what-if)
  ├── Merge to main → auto-deploy to dev
  ├── Manual trigger → deploy to uat
  └── Manual trigger + approval → deploy to prod
  │
  ▼
Azure (per environment)
  ├── Resource Group:  rg-envpinger-<env>
  └── Logic App:       logic-envpinger-<env>
        Trigger: HTTP GET/POST
        Response: { "message": "Hi from <env>", ... }
```

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | >= 2.50 | Includes Bicep. Handles auth, deployments, and IaC. |
| [Git](https://git-scm.com/) | >= 2.x | Source control |

You also need an Azure subscription where you can create Resource Groups, Logic Apps,
and Service Principals.

## Quick Start

### 1. Clone

```
git clone https://github.com/<your-org>/env-pinger-logic-apps-azure.git
cd env-pinger-logic-apps-azure
```

### 2. Log in to Azure

```
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Create a Service Principal (one-time)

```
az ad sp create-for-rbac --name sp-envpinger --role Contributor --scopes /subscriptions/<your-subscription-id> --json-auth
```

Save the JSON output — you'll need it for GitHub Actions (step 5).

### 4. Deploy to dev

```
az group create --name rg-envpinger-dev --location eastus
az deployment group create --resource-group rg-envpinger-dev --template-file infra/main.bicep --parameters infra/environments/dev.bicepparam
```

Test it:

```
curl "<callback-url-from-deployment-output>"
```

You should see: `{"message":"Hi from dev","resource_group":"rg-envpinger-dev","timestamp":"..."}`

### 5. Set up GitHub Actions

Add this secret in **Settings > Secrets and variables > Actions**:

| Secret | Value |
|--------|-------|
| `AZURE_CREDENTIALS` | JSON output from step 3 |

Configure environments in **Settings > Environments**:

| Environment | Protection Rules |
|-------------|-----------------|
| `dev` | None |
| `uat` | None (manual trigger only) |
| `prod` | Required reviewers (1+) |

Now push a branch, open a PR, and the pipeline takes over.

## Useful Commands

### Validate

```
az bicep build --file infra/main.bicep
```

### Preview changes (like terraform plan)

```
az deployment group what-if --resource-group rg-envpinger-dev --template-file infra/main.bicep --parameters infra/environments/dev.bicepparam
```

### Deploy to any environment

```
az group create --name rg-envpinger-<env> --location eastus
az deployment group create --resource-group rg-envpinger-<env> --template-file infra/main.bicep --parameters infra/environments/<env>.bicepparam
```

Where `<env>` is `dev`, `uat`, or `prod`.

## Project Structure

```
├── infra/
│   ├── main.bicep               # Logic App definition (parameterized)
│   └── environments/
│       ├── dev.bicepparam       # environment = 'dev'
│       ├── uat.bicepparam       # environment = 'uat'
│       └── prod.bicepparam      # environment = 'prod'
├── .github/workflows/
│   ├── pr-validate.yml          # PR: syntax check + what-if preview
│   ├── deploy-dev.yml           # Auto-deploy on merge to main
│   ├── deploy-uat.yml           # Manual trigger
│   └── deploy-prod.yml          # Manual trigger + approval
├── PLAN.md
└── README.md
```

## Tearing Down

```
az group delete --name rg-envpinger-dev --yes
az group delete --name rg-envpinger-uat --yes
az group delete --name rg-envpinger-prod --yes
```
