## Input variables
variable "global_configs" {
  type = object(
    {
      subscription_id = string
      location        = string
      mandatory_tags = object(
        {
          app-id        = string
          solution      = string
          businessunit  = string
          costcenter    = string
          srid          = string
          businessowner = string
          support-queue = string
          criticality   = string
          environment   = string
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
  type    = string
  default = "{“version”: “”, “commit-id”: “”, “pipeline-name”:””, “github-repo”: “”}"
}

## Run-time data inputs
data "azurerm_subscription" "current_sub" {
  subscription_id = var.global_configs.subscription_id
}

data "azurerm_client_config" "current_client" {
}


## Run-time variables
locals {

  location        = var.global_configs.location
  app_unique_code = var.global_configs.mandatory_tags.app-id
  environment     = var.global_configs.mandatory_tags.environment
  common_resource_tags = merge(
    var.global_configs.mandatory_tags, {
      deployed-by = var.deployment_info
    }
  )

  subscription_id   = data.azurerm_subscription.current_sub.subscription_id
  subscription_name = data.azurerm_subscription.current_sub.display_name
  client_object_id  = data.azurerm_client_config.current_client.object_id
  client_tenant_id  = data.azurerm_client_config.current_client.tenant_id

}

