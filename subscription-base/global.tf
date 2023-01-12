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
      regional_network_hub = optional(object(
        {
          subscription_id          = string
          vnet_name                = string
          vnet_resource_group_name = string
        }
      ))
      deployment_agent = optional(object(
        {
          subscription_id          = string
          vnet_name                = string
          vnet_resource_group_name = string
          subnet_name              = string
        }
      )),
      central_log_analytics_workspace = optional(object(
        {
          subscription_id     = string
          name                = string
          resource_group_name = string
        }
      ))
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

data "azuread_client_config" "current_tenant" {
  provider = azuread.azuread_spn
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

  subscription_id   = data.azurerm_client_config.current_client.subscription_id
  subscription_name = data.azurerm_subscription.current_sub.display_name
  client_object_id  = data.azurerm_client_config.current_client.object_id
  client_tenant_id  = data.azurerm_client_config.current_client.tenant_id

  regional_hub_subscription_id          = try(var.global_configs.regional_network_hub.subscription_id, null)
  regional_hub_vnet_name                = try(var.global_configs.regional_network_hub.vnet_name, null)
  regional_hub_vnet_resource_group_name = try(var.global_configs.regional_network_hub.vnet_resource_group_name, null)

  deployment_agent_subnet_id = try([format("/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Network/virtualNetworks/%s/subnets/%s",
    var.global_configs.deployment_agent.subscription_id,
    var.global_configs.deployment_agent.vnet_resource_group_name,
    var.global_configs.deployment_agent.vnet_name,
    var.global_configs.deployment_agent.subnet_name
  )], [])

}
