# Terraform — Azure SQL (Directory + Core) for mt-saas v2

This folder deploys the **minimum SQL foundation** for mt-saas v2:
- 1 Resource Group
- 1 Azure SQL logical server (System Assigned Managed Identity enabled)
- 2 Azure SQL Databases:
  - `*_core`
  - `*_directory`
- Optional firewall rules for development convenience

> ⚠️ For a real preprod/prod posture, you will later disable public access and use Private Endpoints + VNet integration.

---

## Prerequisites
- Terraform >= 1.6
- Azure CLI
- An Azure subscription where you can create resources

---

## Quick start (dev)
From the repository root:

```bash
cd infra/terraform/environments/dev

# 1) Login
az login
az account show

# 2) (Optional) set subscription explicitly
# az account set --subscription "<SUBSCRIPTION_ID>"

# 3) Provide the SQL admin password (recommended via env var)
export TF_VAR_sql_admin_password='REPLACE_ME_WITH_A_STRONG_PASSWORD'

# 4) Optionally allow your public IP (copy example -> local tfvars)
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set allowed_client_ip if you want

# 5) Deploy
terraform init
terraform plan
terraform apply
```

Outputs will print:
- `sql_server_fqdn`
- `core_db_name`
- `directory_db_name`

---

## Connect (dev)
If public access is enabled (default) and firewall allows your IP:
- Server: the `sql_server_fqdn` output
- Auth: SQL auth using `sql_admin_login` + your password
- DB: `*_core` or `*_directory`

---

## Important notes
- This baseline sets `minimum_tls_version = 1.2` and keeps it **always set** (removing it later can cause provider errors).
- `AllowAzureServices (0.0.0.0)` is convenient for dev but should be disabled later.

---

## Next hardening steps (recommended order)
1) Add Log Analytics + Diagnostic Settings for SQL
2) Disable public access: `public_network_access_enabled = false`
3) Add Private Endpoint(s) for SQL server + private DNS zone
4) Add Entra admin (Azure AD admin) on SQL server
5) Remove SQL auth for day-to-day (keep break-glass only, or move to AAD-only if you want)

---

## Files
- `modules/sql`: reusable SQL module
- `environments/dev`: dev environment calling the module
