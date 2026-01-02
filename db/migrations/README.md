# DB Migrations (DbUp)

This pack adds a DbUp-based migration system that runs from GitHub Actions.

## What it does
- Applies scripts in filename order
- Tracks applied scripts in `dbo.__schema_migrations`
- Runs against both databases:
  - `db/migrations/directory/*` → directory DB
  - `db/migrations/core/*` → core DB

## Workflow
`.github/workflows/db-migrate-dev.yml`:
1) Azure login via OIDC
2) Terraform init + read outputs (SQL server + DB names)
3) Temporarily allow runner IP on SQL firewall
4) Run DbUp (directory then core)
5) Remove firewall rule (always)

## GitHub Environment "dev" required settings
Secrets:
- AZURE_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_SUBSCRIPTION_ID
- TF_VAR_SQL_ADMIN_PASSWORD   (temporary; SQL auth)

Vars (optional):
- SQL_ADMIN_LOGIN (runner defaults to sqladmin)

## Terraform outputs required
Terraform must expose:
- resource_group_name
- sql_server_name
- sql_server_fqdn
- core_db_name
- directory_db_name
