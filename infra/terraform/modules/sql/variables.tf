variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. westeurope."
  type        = string
}

variable "location_short" {
  description = "Short region code for naming, e.g. weu."
  type        = string
}

variable "name_prefix" {
  description = "Global prefix for naming (lowercase recommended). Example: mtsaas"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/preprod/prod)."
  type        = string
}

variable "sql_admin_login" {
  description = "SQL admin login (local SQL auth). Use a non-obvious name (not 'admin')."
  type        = string
}

variable "sql_admin_password" {
  description = "SQL admin password (sensitive). Provide via TF_VAR_sql_admin_password or a non-committed tfvars."
  type        = string
  sensitive   = true
}

variable "public_network_access_enabled" {
  description = "If false, SQL Server is not reachable via public internet (requires Private Endpoint)."
  type        = bool
  default     = true
}

variable "allow_azure_services" {
  description = "If true, creates AllowAzureServices firewall rule (0.0.0.0). Dev convenience only."
  type        = bool
  default     = true
}

variable "allowed_client_ip" {
  description = "Optional single client public IP to allow (dev convenience). Example: 203.0.113.10"
  type        = string
  default     = null
}

variable "db_sku_name" {
  description = "Azure SQL DB SKU. Examples: Basic, S0, GP_Gen5_2, BC_Gen5_2."
  type        = string
  default     = "S0"
}

variable "db_max_size_gb" {
  description = "Max database size in GB."
  type        = number
  default     = 20
}

variable "db_zone_redundant" {
  description = "Zone redundant DB (more expensive)."
  type        = bool
  default     = false
}

variable "aad_admin_object_id" {
  description = "Optional: Object ID for Azure AD admin (user or group). If set, enables Entra admin on the SQL Server."
  type        = string
  default     = null
}

variable "aad_admin_login_username" {
  description = "Optional: Display name for the Azure AD admin."
  type        = string
  default     = null
}

variable "aad_admin_tenant_id" {
  description = "Optional: Tenant ID for the Azure AD admin. Defaults to current tenant if not set."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
