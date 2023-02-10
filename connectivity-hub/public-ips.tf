variable "public_ip_configs" {
  type = list(object(
    {
      name              = string
      prefix_name       = optional(string)
      allocation_method = optional(string, "Static")
      domain_name_label = optional(string)
      ip_version        = optional(string, "IPv4")
      sku               = optional(string, "Standard")
      sku_tier          = optional(string, "Regional")
      tags              = optional(map(string))
    }
  ))

  default = []
}

locals {
  public_ip_configs = {
    for pip in var.public_ip_configs : pip.name => merge(pip, {
      location            = local.location
      resource_group_name = local.vnet_resource_group_name
      tags                = merge(pip.tags, local.common_resource_tags)
    })
  }
}

resource "azurerm_public_ip" "public_ip" {
  for_each            = local.public_ip_configs
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  allocation_method   = each.value.allocation_method
  domain_name_label   = each.value.domain_name_label
  ip_version          = each.value.ip_version
  sku                 = each.value.sku
  sku_tier            = each.value.sku_tier
  public_ip_prefix_id = try(azurerm_public_ip_prefix.pip_prefix[each.value.prefix_name].id, null)
  tags                = each.value.tags
  lifecycle {
    create_before_destroy = true
  }
}