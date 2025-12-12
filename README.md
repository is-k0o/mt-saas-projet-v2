# mt-saas v2 — Infra starter (Azure SQL via Terraform + GitHub Actions)

This pack is meant to be copied into your repo.

## What it includes
- `infra/terraform/modules/sql`: Azure SQL Server + 2 DBs (core + directory)
- `infra/terraform/environments/dev`: dev environment using azurerm backend (remote state)
- `.github/workflows`: bootstrap + plan + apply pipelines (OIDC)

Open:
- `docs/infra/terraform_github_actions_sql.md`
