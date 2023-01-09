## Run-time variables
locals {

  resource_groups = {
    network_rg = {
      name = local.network_configs.resource_group_name
      tags = merge(local.network_configs.network_tags, local.common_resource_tags)
    }

    admin_rg = {
      name = local.admin_configs.resource_group_name
      tags = merge(local.admin_configs.admin_tags, local.common_resource_tags)
    }

  }

}

## Create a resource groups
resource "azurerm_resource_group" "resource_group" {
  for_each = local.resource_groups
  name     = each.value.name
  location = local.location
  tags     = each.value.tags
}