# CI/CD — Deploy Azure SQL via Terraform (GitHub Actions)

This guide sets up **real CI/CD** for `infra/terraform/environments/dev` using:
- GitHub Actions
- Azure Login via **OIDC** (no long-lived Azure secret) citeturn0search0turn0search3turn0search9
- Remote Terraform state in **Azure Blob Storage (azurerm backend)** citeturn0search2turn0search8

> Note: you will still store **one secret** for the SQL admin password (SQL auth). Later, you can move to Entra-only DB auth and reduce this further.

---

## 1) What you get

Workflows:
- `terraform-bootstrap-tfstate-dev.yml` — creates RG + Storage Account + container for TF state (run once)
- `terraform-plan-infra-dev.yml` — runs `fmt/validate/plan` on PRs to `main`
- `terraform-apply-infra-dev.yml` — runs `apply` on pushes to `main` (recommended: protect with Environment approvals)

Terraform:
- SQL logical server + two DBs (`*_core`, `*_directory`)
- Remote state configured by `backend.dev.hcl`

---

## 2) Azure prerequisites (OIDC trust)

### 2.1 Create an Entra app registration for GitHub Actions
You need an app/service principal that GitHub can impersonate via OIDC. Follow GitHub’s and Microsoft’s OIDC guidance. citeturn0search3turn0search0

The output you need for GitHub:
- **Client ID**
- **Tenant ID**
- **Subscription ID**

### 2.2 Add a federated credential (GitHub OIDC)
Create a federated identity credential on the app so GitHub Actions can authenticate without a client secret. citeturn0search3turn0search21

Recommended subject for environment-protected deploys:
- `repo:<OWNER>/<REPO>:environment:dev`

### 2.3 Assign Azure RBAC roles
At minimum, give the app **Contributor** on the target resource group (dev RG).

For the Terraform state storage account, also grant:
- `Storage Blob Data Contributor` on the **state storage account** (or container).  
This is required for the azurerm backend to read/write state using Entra auth.

---

## 3) GitHub repo setup

### 3.1 Create GitHub Environment: `dev`
In your repo:
- Settings → Environments → **New environment**: `dev`
- (Recommended) Require manual approval for `terraform-apply-infra-dev.yml`.

### 3.2 Add GitHub Secrets (Repository or Environment)
Add these secrets:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_SQL_ADMIN_PASSWORD` (strong password for SQL auth)

OIDC requires workflow permissions `id-token: write`. The workflows already set it. citeturn0search9turn0search13

### 3.3 Add GitHub Variables (Environment variables)
Add these variables under environment `dev`:
- `TFSTATE_RG` (e.g. `rg-mtsaas-v2-tfstate-weu`)
- `TFSTATE_LOCATION` (e.g. `westeurope`)
- `TFSTATE_STORAGE_ACCOUNT` (e.g. `mtsaasv2tfstateweu01`)
- `TFSTATE_CONTAINER` (e.g. `tfstate`)

---

## 4) Configure the backend file

Edit:
- `infra/terraform/environments/dev/backend.dev.hcl`

Set your real values:
- `resource_group_name`
- `storage_account_name` (globally unique, 3–24 lowercase letters/numbers)
- `container_name`
- `key`

---

## 5) First run (bootstrap)

Run the bootstrap workflow once:
- Actions → **bootstrap-tfstate-dev** → Run workflow

This creates the remote state container.

---

## 6) Normal workflow

### PR to main
- Open a PR that changes `infra/terraform/**`
- The **plan** workflow runs and uploads an artifact.

### Merge to main
- On merge/push to `main`, the **apply** workflow runs.
- If you enabled environment approvals, it will wait for approval.

---

## 7) Troubleshooting quick hits

- **OIDC login fails** → check federated credential subject/issuer/audience. citeturn0search3turn0search0
- **Backend cannot write state** → missing `Storage Blob Data Contributor` on the state storage account/container.
- **SQL connect issues** → dev firewall rules might block your IP; set `allowed_client_ip` (local only) or keep public access on for dev.

---

## 8) Next hardening steps (after schema/migrations work)
1) Disable public SQL access + Private Endpoint (preprod)
2) Entra admin on SQL server, reduce SQL auth usage
3) Diagnostic settings + Defender for SQL
