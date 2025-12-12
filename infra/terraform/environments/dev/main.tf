data "azurerm_client_config" "current" {}

module "sql" {
  source = "../../modules/sql"

  resource_group_name = var.resource_group_name
  location            = var.location
  location_short      = var.location_short
  name_prefix         = var.name_prefix
  environment         = var.environment

  sql_admin_login    = var.sql_admin_login
  sql_admin_password = var.sql_admin_password

  public_network_access_enabled = var.public_network_access_enabled
  allow_azure_services          = var.allow_azure_services
  allowed_client_ip             = var.allowed_client_ip

  db_sku_name       = var.db_sku_name
  db_max_size_gb    = var.db_max_size_gb
  db_zone_redundant = var.db_zone_redundant

  # Optional Entra admin (recommended later). If you want it now, set aad_admin_object_id + tenant_id.
  aad_admin_object_id      = var.aad_admin_object_id
  aad_admin_login_username = var.aad_admin_login_username
  aad_admin_tenant_id      = coalesce(var.aad_admin_tenant_id, data.azurerm_client_config.current.tenant_id)

  tags = var.tags
}
