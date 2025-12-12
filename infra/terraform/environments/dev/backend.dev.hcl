# Terraform remote state backend (Azure Blob Storage)
# NOTE: This file is NOT a secret, but it is environment-specific.
# Change names to your own.

resource_group_name  = "rg-mtsaas-v2-tfstate-weu"
storage_account_name = "mtsaasv2tfstateweu01"  # must be globally unique (3-24 lowercase letters/numbers)
container_name       = "tfstate"
key                  = "mt-saas-v2/dev/sql.tfstate"
