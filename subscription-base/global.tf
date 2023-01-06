## Input variables
variable "global_configs" {
  type = object(
    {
      subscription_id = string
      location        = string
      mandatory_tags = object(
        {
          app-id        = string
          businessunit  = string
          costcenter    = string
          srid          = string
          businessowner = string
          support-queue = string
          criticality   = string
        }
      )
    }
  )

  validation {
    condition     = length(var.global_configs.mandatory_tags.app-id) == 4
    error_message = "The 'app-id' tag value must be exactly 4 characters long."
  }

}

variable "deployment_info" {
  type = object(
    {
      environment = string
      deployed_by = string
    }
  )

  default = {
    deployed_by = "{“version”: “”, “commit-id”: “”, “pipeline-name”:””, “github-repo”: “”}"
    environment = "prod"
  }
}

## Run-time data inputs
data "azurerm_subscription" "current_sub" {
}

data "azurerm_client_config" "current_client" {
}

data "azuread_client_config" "current_tenant" {
  provider = azuread.azuread_spn
}

## Run-time variables
locals {

  location        = var.global_configs.location
  app_unique_code = var.global_configs.mandatory_tags.app-id
  environment     = var.deployment_info.environment
  common_resource_tags = merge(
    var.global_configs.mandatory_tags, {
      deployed-by = var.deployment_info.deployed_by,
      environment = var.deployment_info.environment
    }
  )

  subscription_id   = data.azurerm_client_config.current_client.subscription_id
  subscription_name = data.azurerm_subscription.current_sub.display_name

}