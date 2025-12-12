output "resource_group_name" {
  value = module.sql.resource_group_name
}

output "sql_server_name" {
  value = module.sql.sql_server_name
}

output "sql_server_fqdn" {
  value = module.sql.sql_server_fqdn
}

output "core_db_name" {
  value = module.sql.core_db_name
}

output "directory_db_name" {
  value = module.sql.directory_db_name
}
