variable "firewall_network_rule_collection" {
  type = list(object(
    {
      name     = string
      priority = number
      action   = string
      rules = list(object(
        {
          name                  = string
          description           = optional(string)
          source_addresses      = optional(list(string))
          source_ip_groups      = optional(list(string))
          destination_addresses = optional(list(string))
          destination_ip_groups = optional(list(string))
          destination_fqdns     = optional(list(string))
          destination_ports     = optional(list(string))
          protocols             = optional(list(string))
        }
      ))
    }
  ))
  default = []
}

locals {

  firewall_network_rule_collection = {
    for rule_collection in var.firewall_network_rule_collection : lower(format("%s/%s", local.vnet_resource_group_name, rule_collection.name)) => merge(rule_collection, {
      fw_network_rule_key = lower(format("%s/%s", local.vnet_resource_group_name, rule_collection.name))
      fw_key              = lower(format("%s/%s", local.vnet_resource_group_name, var.firewall_config.name))
    })
  }
}

resource "azurerm_firewall_network_rule_collection" "firewall_network_rule_collection" {
  for_each            = local.firewall_network_rule_collection
  name                = each.value.name
  azure_firewall_name = azurerm_firewall.firewall[each.value.fw_key].name
  resource_group_name = local.vnet_resource_group_name
  priority            = each.value.priority
  action              = each.value.action

  dynamic "rule" {

    for_each = try(length(each.value.rules), 0) > 0 ? each.value.rules : []

    content {

      name                  = rule.value.name
      description           = rule.value.description
      source_addresses      = rule.value.source_addresses
      source_ip_groups      = rule.value.source_ip_groups
      destination_addresses = rule.value.destination_addresses
      destination_ip_groups = rule.value.destination_ip_groups
      destination_fqdns     = rule.value.destination_fqdns
      destination_ports     = rule.value.destination_ports
      protocols             = rule.value.protocols
    }
  }
}
