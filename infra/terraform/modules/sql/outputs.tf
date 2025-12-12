output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "sql_server_name" {
  value = azurerm_mssql_server.sql.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_server_id" {
  value = azurerm_mssql_server.sql.id
}

output "core_db_name" {
  value = azurerm_mssql_database.core.name
}

output "directory_db_name" {
  value = azurerm_mssql_database.directory.name
}
