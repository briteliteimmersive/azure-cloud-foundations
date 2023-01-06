terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.27.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.global_configs.subscription_id
  features {}
}

provider "azuread" {
  alias = "azuread_spn"
}

provider "azurerm" {
  alias           = "hub-sub"
  subscription_id = local.regional_hub_subscription_id
  features {}
}