## Input variables
variable "firewall_config" {
  type = object({
    name                   = string
    sku_tier               = string
    sku_name               = string
    subnet_name            = optional(string, "AzureFirewallSubnet")
    primary_public_ip_name = string
    associated_public_ips  = optional(list(string), [])
    tags                   = optional(map(string), {})
  })
}

locals {

  firewall_config = var.firewall_config

  firewall = {
    lower(format("%s/%s", local.vnet_resource_group_name, var.firewall_config.name)) = merge(var.firewall_config, {
      firewall_key = lower(format("%s/%s", local.vnet_resource_group_name, var.firewall_config.name))
    })
  }

}

data "azurerm_subnet" "fw_subnet" {
  name                 = local.firewall_config.subnet_name
  virtual_network_name = local.vnet_name
  resource_group_name  = local.vnet_resource_group_name
}

resource "azurerm_firewall" "firewall" {
  for_each            = local.firewall
  name                = each.value.name
  location            = local.location
  resource_group_name = local.vnet_resource_group_name
  sku_name            = each.value.sku_name
  sku_tier            = each.value.sku_tier

  ip_configuration {
    name                 = each.value.primary_public_ip_name
    subnet_id            = data.azurerm_subnet.fw_subnet.id
    public_ip_address_id = azurerm_public_ip.public_ip[each.value.primary_public_ip_name].id
  }

  dynamic "ip_configuration" {
    for_each = each.value.associated_public_ips
    content {
      name                 = ip_configuration.value
      public_ip_address_id = azurerm_public_ip.public_ip[ip_configuration.value].id
    }
  }

  tags = merge(each.value.tags, local.common_resource_tags)
}
