# CURRENT_STATE — mt-saas v2

**Last updated:** 2025-12-12  
**Repo:** is-k0o/mt-saas-projet-v2 (private)  
**Environment:** dev

---

## 1) What works right now (✅)

### CI/CD (GitHub Actions)
- ✅ Workflows present:
  - `bootstrap-tfstate-dev` (manual)
  - `terraform-plan-infra-dev` (PR)
  - `terraform-apply-infra-dev` (push main / manual)
- ✅ Azure login via OIDC works (no client secret).
- ✅ Remote Terraform state backend works (Azure Storage).

### Terraform backend (state)
- ✅ Bootstrap creates:
  - Resource Group (tfstate)
  - Storage Account (tfstate)
  - Container `tfstate`
- ✅ Terraform init uses `backend.dev.hcl` successfully.

### Infra deployed
- ✅ Base infra deployed via Terraform:
  - Resource Group (dev)
  - Azure SQL logical server
  - Databases: `*_core`, `*_directory`
  - Public access (dev mode), firewall rules as configured

---

## 2) Identity / Access (current)
- Service principal used by GitHub Actions:
  - DisplayName: `gh-oidc-terraform`
  - Federated credential:
    - issuer: `https://token.actions.githubusercontent.com`
    - subject: `repo:is-k0o/mt-saas-projet-v2:environment:dev`
- GitHub secrets configured (dev environment):
  - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
  - `TF_VAR_SQL_ADMIN_PASSWORD` (temporary, dev)

---

## 3) Known constraints / assumptions
- “Public-first” deployment strategy:
  - We prioritize a working pipeline and functional DB migrations while SQL is public.
  - Hardening (Private Endpoints, VNet integration, etc.) comes later, step-by-step.
- Terraform backend configuration is intentionally split:
  - `infra/terraform/environments/dev/backend.dev.hcl`
  - GitHub Environment vars `TFSTATE_*`
  - These must stay consistent.

---

## 4) Next steps (🔜)

### Data layer (SQL)
1) Add `db/migrations/{directory,core}/` with ordered scripts:
   - init tables
   - constraints/indexes
   - RLS + stored procedures (e.g., finalize posting)
2) Decide migrations runner:
   - Option A: DbUp (recommended)
   - Option B: SQL scripts executed in order (simple)

### DB deployment pipeline
3) Add a GitHub Action workflow `db-migrate-dev` that:
   - temporarily opens SQL firewall for runner IP
   - executes migrations (DbUp or ordered scripts)
   - closes firewall rule

### Later hardening (not now)
- Disable public access, add Private Endpoint + private DNS
- Use Entra-only DB auth (reduce SQL auth)
- Diagnostics + Defender + monitoring

---

## 5) Open questions
- Do we set Azure AD admin on SQL server now, or keep SQL auth for dev migrations?
- Final decision on migration tool (DbUp vs scripts).
