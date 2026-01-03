# CURRENT_STATE — mt-saas v2

**Last updated:** 2026-01-03  
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
- ✅ Azure SQL logical server (westeurope)
- ✅ Databases:
  - `mtsaas_dev_directory`
  - `mtsaas_dev_core`
- ✅ Public network access enabled (dev mode).
- ✅ Firewall baseline: `AllowAzureServices (0.0.0.0)`
  + workflow adds an ephemeral rule for the GitHub runner IP during `db-migrate-dev`.

---

## 2) Identity / Access (current)

### GitHub → Azure (OIDC)
- Service principal used by GitHub Actions: `gh-oidc-terraform`
- Federated credential (env-based):
  - issuer: `https://token.actions.githubusercontent.com`
  - subject: `repo:is-k0o/mt-saas-projet-v2:environment:dev`
  - audience: `api://AzureADTokenExchange`

### GitHub secrets / vars (dev)
- Secrets:
  - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
  - `TF_VAR_SQL_ADMIN_PASSWORD` (temporary, dev)
- Repo / env variables:
  - `TFSTATE_RG`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`, `TFSTATE_LOCATION`
  - `SQL_ADMIN_LOGIN` (optional; defaults to `sqladmin`)

---

## 3) DB migrations (DbUp) — status

### Runner project
- ✅ .NET console: `src/migrations/ComptaPlus.Migrations` (DbUp)
- ✅ Journal table: `dbo.__schema_migrations`
- ✅ Execution:
  - directory DB first
  - core DB second
  - transaction **per script file** (`WithTransactionPerScript()`)

### Scripts (expected in repo)
- Directory:
  - `db/migrations/directory/0001_init.sql`
- Core:
  - `db/migrations/core/0001_init.sql`
  - `db/migrations/core/0002_finalize_posting_sproc.sql`
  - `db/migrations/core/0003_add_tenant_columns_children.sql`
  - `db/migrations/core/0004_rls.sql`
  - `db/migrations/core/0005_core_runtime_role.sql`

### Current schema (dev)

#### Directory DB (`dir`)
- ✅ Tables:
  - `dir.cabinet`, `dir.company`, `dir.user_membership`
- ✅ `dbo.__schema_migrations`

#### Core DB (`core` + `sec`)
- ✅ Tables under `core`:
  - `audit_event`, `document`, `document_line`, `exception_comment`, `exception_queue`,
    `party`, `payment_event`, `posting_header`, `posting_line`, `[rule]`
- ✅ Stored proc: `core.usp_finalize_posting`
- ✅ RLS objects (defense-in-depth):
  - schema `sec`
  - stored proc to set tenant context: `sec.usp_set_tenant_context(@cabinet_id, @company_id)`
  - predicate function(s) in `sec` (used by the security policy)
  - security policy enabled (ex: `sec.CompanySecurityPolicy`)
- ✅ Runtime DB role for the future API identity:
  - role: `app_runtime`
  - goal: later, add the API managed identity / Entra users as members of this role

---

## 4) Sanity checks (manual)

- ✅ Script: `db/sanity/core_sanity_check.sql`
  - outputs a small **OK/WARN/KO** report (tenant columns, RLS objects, policy enabled, basic consistency checks)
  - note: if the DB has no data yet, the “sample tenant selected” check will warn/KO (normal)

---

## 5) Known gotchas

- **RLS bypass with db_owner:** if you test RLS while connected as `db_owner`/admin, results can be misleading.
  Use a low-priv user or `EXECUTE AS USER = 'api_local'` with a `WITHOUT LOGIN` test user.
- **Partial drift on script failure:** if a large script fails before the journal is written, objects can exist but DbUp will retry.
  Dev fix = drop/recreate DB(s) and rerun migrations.
- **Reserved keyword:** `rule` is reserved in SQL Server → always reference it as `core.[rule]`.
- **Repo hygiene:** make sure your ignore file is `.gitignore` (not `gitignore`), otherwise Git won’t ignore anything.

---

## 6) Next steps (🔜)

1) Directory: design the “runtime” access surface (views/procs) used by the API to resolve slugs → IDs and verify membership.
2) API skeleton (auth + routes) + DB access pattern:
   - resolve tenant via Directory
   - call `sec.usp_set_tenant_context`
   - read/write in Core (RLS as hard-stop)
3) Storage account + containers (documents) + metadata contract (tenant scope).
4) Minimal seed data (dev-only) so RLS tests and API smoke tests are fast.
5) Prepare `preprod` env once dev loop is stable (then start the private networking hardening).
