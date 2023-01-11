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
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
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

provider "github" {
  base_url = var.gh_base_url
  owner    = var.gh_org_name
  token    = var.gh_token
}