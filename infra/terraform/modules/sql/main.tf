terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

locals {
  # Azure SQL Server name must be globally unique, lowercase, and 1-63 chars.
  sql_server_name = lower(substr("${var.name_prefix}-${var.environment}-${var.location_short}-sql-${random_string.suffix.result}", 0, 63))

  core_db_name      = "${var.name_prefix}_${var.environment}_core"
  directory_db_name = "${var.name_prefix}_${var.environment}_directory"
}

resource "azurerm_mssql_server" "sql" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  minimum_tls_version           = "1.2"
  public_network_access_enabled = var.public_network_access_enabled

  identity {
    type = "SystemAssigned"
  }

  dynamic "azuread_administrator" {
    for_each = var.aad_admin_object_id == null ? [] : [1]
    content {
      login_username = coalesce(var.aad_admin_login_username, "AzureAD Admin")
      object_id      = var.aad_admin_object_id
      tenant_id      = var.aad_admin_tenant_id
    }
  }

  tags = var.tags
}

# Allow Azure services (optional). In preprod/prod you typically disable this and use Private Endpoints.
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  count            = var.public_network_access_enabled && var.allow_azure_services ? 1 : 0
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Allow a specific client IP (optional, dev convenience).
resource "azurerm_mssql_firewall_rule" "allow_client_ip" {
  count            = var.public_network_access_enabled && var.allowed_client_ip != null ? 1 : 0
  name             = "AllowClientIp"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = var.allowed_client_ip
  end_ip_address   = var.allowed_client_ip
}

resource "azurerm_mssql_database" "core" {
  name      = local.core_db_name
  server_id = azurerm_mssql_server.sql.id

  sku_name     = var.db_sku_name
  max_size_gb  = var.db_max_size_gb
  zone_redundant = var.db_zone_redundant

  tags = var.tags
}

resource "azurerm_mssql_database" "directory" {
  name      = local.directory_db_name
  server_id = azurerm_mssql_server.sql.id

  sku_name     = var.db_sku_name
  max_size_gb  = var.db_max_size_gb
  zone_redundant = var.db_zone_redundant

  tags = var.tags
}
