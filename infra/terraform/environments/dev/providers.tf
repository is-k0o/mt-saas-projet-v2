terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
  }

  # Remote state is configured via `backend.dev.hcl` at init-time.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
