## Run-time variables
locals {

  resource_groups = {
    fw_rgp = {
      name = local.firewall_config.resource_group_name
      tags = merge(local.firewall_config.tags, local.common_resource_tags)
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