## Input variables
variable "nsg_configs" {
  type = list(object({
    name = string
    rules = optional(list(object({
      name                         = string
      priority                     = number
      direction                    = string
      access                       = string
      protocol                     = string
      destination_port_range       = optional(string)
      destination_port_ranges      = optional(list(string))
      source_address_prefix        = optional(string)
      source_address_prefixes      = optional(list(string))
      destination_address_prefix   = optional(string)
      destination_address_prefixes = optional(list(string))
      source_port_range            = optional(string)
      source_port_ranges           = optional(list(string))
    })))
  }))

}

## Create NSGs
locals {

  nsgs = {
    for nsg in var.nsg_configs :
    lower(format("%s/%s", local.resource_groups.network_rg.name, nsg.name)) => merge(nsg, {
      nsg_key = lower(format("%s/%s", local.resource_groups.network_rg.name, nsg.name))
    })
  }

  nsg_keys_by_name = {
    for nsg_key, nsg in local.nsgs : nsg.name => nsg_key
  }

}

resource "azurerm_network_security_group" "nsg" {
  for_each            = local.nsgs
  name                = each.value.name
  location            = local.location
  resource_group_name = azurerm_resource_group.resource_group["network_rg"].name
  tags                = azurerm_resource_group.resource_group["network_rg"].tags
}

locals {
  nsg_rule_list = flatten(
    [
      for nsg_key, nsg in local.nsgs : [
        for rule in coalesce(nsg.rules, []) : merge(rule,
          {
            nsg_key      = nsg_key
            nsg_rule_key = format("%s/%s", nsg_key, rule.name)
          }
        )
      ]
    ]
  )

  nsg_rules = {
    for rule in local.nsg_rule_list : rule.nsg_rule_key => rule
  }
}

resource "azurerm_network_security_rule" "nsg_rule" {
  for_each                     = local.nsg_rules
  name                         = each.value.name
  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  destination_port_range       = each.value.destination_port_range
  source_address_prefix        = each.value.source_address_prefix
  destination_address_prefix   = each.value.destination_address_prefix
  destination_port_ranges      = each.value.destination_port_ranges
  source_address_prefixes      = each.value.source_address_prefixes
  destination_address_prefixes = each.value.destination_address_prefixes
  resource_group_name          = azurerm_network_security_group.nsg[each.value.nsg_key].resource_group_name
  source_port_ranges           = each.value.source_port_ranges
  network_security_group_name  = azurerm_network_security_group.nsg[each.value.nsg_key].name
}