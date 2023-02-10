variable "public_ip_prefixes" {
  type = list(object(
    {
      name          = string
      prefix_length = number
      sku           = optional(string)
      ip_version    = optional(string)
      tags          = optional(map(string))
    }
  ))

  default = []
}

locals {
  public_ip_prefixes = {
    for prefix in var.public_ip_prefixes : prefix.name => merge(prefix,
      {
        location            = local.location
        resource_group_name = local.vnet_resource_group_name
        tags                = merge(prefix.tags, local.common_resource_tags)
    })
  }
}

resource "azurerm_public_ip_prefix" "pip_prefix" {
  for_each            = local.public_ip_prefixes
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  sku                 = each.value.sku
  ip_version          = each.value.ip_version
  prefix_length       = each.value.prefix_length
  tags                = each.value.tags
}