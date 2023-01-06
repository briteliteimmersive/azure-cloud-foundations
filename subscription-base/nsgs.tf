## Input variables
variable "nsg_configs" {
  type = list(object({
    serial_no       = number
    name            = optional(string)
    environment     = optional(string)
    app_unique_code = optional(string)
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
  default = []
}

## Create NSGs
locals {

  ## Example = "OZI-GX-NP-SUB013-WE-NSG-COPS-N001" 
  nsg_naming_format = "%s-%s-nsg-%s-%s%03d"

  nsgs = {
    for nsg in var.nsg_configs :
    lower(format("nsg-%d", nsg.serial_no)) => merge(nsg, {
      resource_key = lower(format("nsg-%d", nsg.serial_no))
      name = lower(coalesce(nsg.name, format(
        local.nsg_naming_format,
        local.subscription_name,
        local.az_location_code,
        coalesce(nsg.app_unique_code, local.app_unique_code),
        try(lookup(local.env_code_map, nsg.environment), local.infra_env_code),
        nsg.serial_no
      )))
    })
  }

  #   nsg_list = flatten([
  #     for vnet_key, vnet in local.virtual_networks : [
  #       for nsg in coalesce(vnet.network_security_groups, []) : merge(nsg, {
  #         vnet_key = vnet_key
  #         nsg_key = lower(format(
  #           "%s-nsg-%s%d",
  #           vnet_key,
  #           try(lookup(local.env_code_map, nsg.nsg_environment), local.infra_env_code),
  #           nsg.nsg_serial_no
  #         ))
  #         name = lower(coalesce(nsg.nsg_name, format(
  #           local.nsg_naming_format,
  #           local.subscription_name,
  #           local.az_location_code,
  #           coalesce(nsg.nsg_app_unique_code, local.app_unique_code),
  #           try(lookup(local.env_code_map, nsg.nsg_environment), local.infra_env_code),
  #           nsg.nsg_serial_no
  #         )))
  #       })
  #     ]
  #   ])

  #   nsgs = {
  #     for nsg in local.nsg_list : nsg.nsg_key => nsg
  #   }

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
            nsg_rule_key = "${nsg_key}-${rule.name}"
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