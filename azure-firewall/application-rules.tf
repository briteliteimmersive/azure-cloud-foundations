variable "firewall_app_rule_collection" {
  type = list(object(
    {
        name = string
        priority = number
        action = string
        rules = list(object(
            {
                name = string
                description = optional(string)
                source_addresses = optional(list(string))
                source_ip_ranges = optional(list(string))
                fqdn_tags = optional(list(string))
                target_fqdns = optional(list(string))
                protocol = optional(list(object(
                    {
                        port = number
                        type = string
                    }
                )))
            }
        ))
    }
  ))
  default = []
}

locals {
  
  firewall_app_rule_collection = {
    for rule_collection in var.firewall_app_rule_collection: lower(format("%s/%s", local.resource_groups.fw_rgp.name, rule_collection.name)) => merge(rule_collection, {
        fw_app_rule_key = lower(format("%s/%s", local.resource_groups.fw_rgp.name, rule_collection.name))
        fw_key = lower(format("%s/%s", var.firewall_config.resource_group_name, var.firewall_config.name))
    })
  }
}

resource "azurerm_firewall_application_rule_collection" "firewall_app_rule_collection" {
    for_each = local.firewall_app_rule_collection
  name                = each.value.name
  azure_firewall_name = azurerm_firewall.firewall[each.value.fw_key].name
  resource_group_name = azurerm_resource_group.resource_group["fw_rgp"].name
  priority            = each.value.priority
  action              = each.value.action

  dynamic "rule" {

    for_each = try(length(each.value.rules), 0) > 0 ? each.value.rules : []

    content {

        name = rule.value.name
        source_addresses = rule.value.source_addresses
        target_fqdns = rule.value.target_fqdns

        dynamic "protocol" {
            for_each = try(length(rule.value.protocol), 0) > 0 ? rule.value.protocol : []
            content {
                port = protocol.value.port
                type = protocol.value.type
            }

        }
    }
  }
}
