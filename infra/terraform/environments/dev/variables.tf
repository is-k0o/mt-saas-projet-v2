variable "resource_group_name" {
  type        = string
  description = "Resource group name for dev."
  default     = "rg-mtsaas-v2-dev-weu"
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "westeurope"
}

variable "location_short" {
  type        = string
  description = "Short region code for naming."
  default     = "weu"
}

variable "name_prefix" {
  type        = string
  description = "Naming prefix (lowercase recommended)."
  default     = "mtsaas"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "dev"
}

variable "sql_admin_login" {
  type        = string
  description = "SQL admin login."
  default     = "sqladmin"
}

variable "sql_admin_password" {
  type        = string
  description = "SQL admin password (sensitive)."
  sensitive   = true
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Public access enabled (dev convenience)."
  default     = true
}

variable "allow_azure_services" {
  type        = bool
  description = "Allow Azure services rule (0.0.0.0). Dev convenience."
  default     = true
}

variable "allowed_client_ip" {
  type        = string
  description = "Optional: your public IP to allow for dev."
  default     = null
}

variable "db_sku_name" {
  type        = string
  description = "Azure SQL DB SKU."
  default     = "S0"
}

variable "db_max_size_gb" {
  type        = number
  description = "Max DB size (GB)."
  default     = 20
}

variable "db_zone_redundant" {
  type        = bool
  description = "Zone redundancy."
  default     = false
}

variable "aad_admin_object_id" {
  type        = string
  description = "Optional: Entra admin object id (user or group)."
  default     = null
}

variable "aad_admin_login_username" {
  type        = string
  description = "Optional: Entra admin display name."
  default     = null
}

variable "aad_admin_tenant_id" {
  type        = string
  description = "Optional: Entra tenant id for admin."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags."
  default = {
    project     = "mt-saas-v2"
    environment = "dev"
    owner       = "you"
  }
}
