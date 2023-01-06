## Run-time variables
locals {

  ## Example - "OZI-WE-NP-RG-APPC-X001"
  rg_naming_format = "%s-%s-%s-rg-%s-%s%03d"

  resource_groups = {
    network_rg = {
      name = lower(coalesce(
        local.network_configs.resource_group_name,
        format(
          local.rg_naming_format,
          local.subscription_naming_prefix,
          local.az_location_code,
          local.subsription_env_code,
          local.app_unique_code,
          local.infra_env_code,
          1
        )
      ))
      tags = merge(local.network_configs.network_tags, local.common_resource_tags)
    }

    # admin_rgp = coalesce(
    #     var.admin_configs.resource_group_name,
    #     format(
    #         local.rg_naming_format,
    #         local.subscription_naming_prefix,
    #         local.az_location_code,
    #         local.subsription_env_code,
    #         local.app_unique_code,
    #         local.infra_env_code,
    #         2
    #     )
    # )

  }

}

## Create a resource groups
resource "azurerm_resource_group" "resource_group" {
  for_each = local.resource_groups
  name     = each.value.name
  location = local.location
  tags     = each.value.tags
}