# CURRENT_STATE — mt-saas v2

**Last updated:** 2026-01-02  
**Repo:** is-k0o/mt-saas-projet-v2 (private)  
**Environment:** dev

---

## 1) What works right now (✅)

### CI/CD (GitHub Actions)
- ✅ Workflows present:
  - `bootstrap-tfstate-dev` (manual) — creates TF backend (RG/SA/container)
  - `terraform-plan-infra-dev` (PR) — plan only
  - `terraform-apply-infra-dev` (push main / manual) — deploys infra
  - `db-migrate-dev` (manual / push main) — runs DbUp migrations
- ✅ Azure login via OIDC works (no client secret).

### Terraform backend (remote state)
- ✅ Bootstrap creates:
  - Resource Group (tfstate)
  - Storage Account (tfstate)
  - Container `tfstate`
- ✅ `terraform init -backend-config=backend.dev.hcl` succeeds.

### Infra deployed (dev)
- ✅ Resource Group: `rg-mtsaas-v2-dev-weu`
- ✅ Azure SQL logical server: `mtsaas-dev-weu-sql-2qb3j4` (westeurope)
- ✅ Databases:
  - `mtsaas_dev_directory`
  - `mtsaas_dev_core`
- ✅ Public network access enabled (dev mode).
- ✅ Firewall baseline: `AllowAzureServices (0.0.0.0)`  
  + workflow adds an ephemeral rule for the GitHub runner IP during `db-migrate-dev`.

---

## 2) Identity / Access (current)

### GitHub → Azure (OIDC)
- Service principal used by GitHub Actions:
  - DisplayName: `gh-oidc-terraform`
  - Federated credential:
    - issuer: `https://token.actions.githubusercontent.com`
    - subject: `repo:is-k0o/mt-saas-projet-v2:environment:dev`
    - audience: `api://AzureADTokenExchange`

### GitHub secrets / vars (dev)
- Secrets:
  - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
  - `TF_VAR_SQL_ADMIN_PASSWORD` (temporary, dev)
- Repo variables:
  - `TFSTATE_RG`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`, `TFSTATE_LOCATION`

> Note: `sql_admin_login` uses Terraform default `sqladmin` (no repo var needed unless you change it).

---

## 3) DB migrations (DbUp) — status

### Runner project
- ✅ .NET console: `src/migrations/ComptaPlus.Migrations` (DbUp)
- ✅ Journal table: `dbo.__schema_migrations`
- ✅ Scripts:
  - `db/migrations/directory/0001_init.sql`
  - `db/migrations/core/0001_init.sql`
  - `db/migrations/core/0002_finalize_posting_sproc.sql`

### Migration results (dev)
- ✅ Directory DB:
  - `dir.cabinet`, `dir.company`, `dir.user_membership`
  - `dbo.__schema_migrations`
- ✅ Core DB:
  - Tables visible under schema `core`:
    - `audit_event`, `document`, `document_line`, `exception_comment`, `exception_queue`,
      `party`, `payment_event`, `posting_header`, `posting_line`, `rule`
  - Stored proc: `core.usp_finalize_posting`
  - `dbo.__schema_migrations`

---

## 4) Known gotchas (documented)

- **Order matters:** TF backend must exist before `terraform init`.
- **Firewall:** GitHub runner IP must be allowed temporarily for DbUp (workflow handles it).
- **Reserved keyword:** `rule` is reserved in T-SQL — always reference it as `[rule]` in scripts.
- **Drift risk on partial failure:** if `0001_init.sql` fails mid-script, some objects may exist even if the journal did not record the script.  
  Dev fix = drop the DB(s) and re-run migrations.

---

## 5) Next steps (🔜)

1) Decide SQL authentication posture for dev/preprod:
   - Keep SQL auth for now (fast), later add Entra admin + Entra-only.
2) Add seed data scripts (minimal) for quick API testing.
3) Start API skeleton (routes + membership checks) and wire it to directory/core DBs.
4) Add Storage Account + containers (documents) when the API needs it.
5) Create `preprod` env (separate TF state + DBs) once dev loop is stable.
