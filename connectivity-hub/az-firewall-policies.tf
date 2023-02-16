## Input variables
variable "firewall_policies" {
  type = list(object({
    name = string
    dns = optional(object({
      proxy_enabled = optional(bool)
      servers       = optional(list(string))
      sku           = optional(string, "Standard")
      tags          = optional(map(string))
    }))
    rule_groups = optional(list(object(
      {
        name     = string
        priority = number
        application_rule_collection = optional(list(object(
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
                destination_fqdns     = optional(list(string))
                destination_fqdn_tags = optional(list(string))
                protocols = optional(list(object(
                  {
                    port = number
                    type = string
                  }
                )), [])
              }
            ))
          }
        )), [])
        nat_rule_collection = optional(list(object(
          {
            name     = string
            priority = number
            action   = string
            rules = list(object(
              {
                name                = string
                protocols           = list(string)
                source_addresses    = optional(list(string))
                source_ip_groups    = optional(list(string))
                destination_address = optional(string)
                destination_ports   = optional(list(string))
                translated_address  = string
                translated_port     = number
              }
            ))
          }
        )), [])
        network_rule_collection = optional(list(object(
          {
            name     = string
            priority = number
            action   = string
            rules = list(object(
              {
                name                  = string
                protocols             = list(string)
                source_addresses      = optional(list(string))
                source_ip_groups      = optional(list(string))
                destination_addresses = optional(list(string))
                destination_ip_groups = optional(list(string))
                destination_fqdns     = optional(list(string))
                destination_ports     = optional(list(string))
              }
            ))
          }
        )), [])
      }
    )), [])
  }))

  default = []
}

locals {

  firewall_policies = {
    for firewall_policy in var.firewall_policies : lower(format("%s/%s", local.vnet_resource_group_name, firewall_policy.name)) => merge(firewall_policy, {
      fw_policy_key = lower(format("%s/%s", local.vnet_resource_group_name, firewall_policy.name))
    })
  }

  firewall_collection_group_list = flatten([
    for policy_key, policy_config in local.firewall_policies : [
      for collection_group in policy_config.rule_groups : merge(collection_group, {
        fw_collection_group_key = lower(format("%s/%s", policy_key, collection_group.name))
        fw_policy_key           = policy_key
      })
    ]
  ])

  firewall_collection_groups = {
    for collection_group in local.firewall_collection_group_list : collection_group.fw_collection_group_key => collection_group
  }
}


resource "azurerm_firewall_policy" "policy" {
  for_each            = local.firewall_policies
  name                = each.value.name
  location            = local.location
  resource_group_name = local.vnet_resource_group_name

  dynamic "dns" {
    for_each = try(length(each.value.dns) > 0, false) ? [each.value.dns] : []

    content {
      proxy_enabled = dns.value.proxy_enabled
      servers       = dns.value.servers
    }
  }

}

resource "azurerm_firewall_policy_rule_collection_group" "rule_collection_group" {
  for_each           = local.firewall_collection_groups
  name               = each.value.name
  priority           = each.value.priority
  firewall_policy_id = azurerm_firewall_policy.policy[each.value.fw_policy_key].id

  dynamic "application_rule_collection" {

    for_each = each.value.application_rule_collection

    content {
      name     = application_rule_collection.value.name
      priority = application_rule_collection.value.priority
      action   = application_rule_collection.value.action

      dynamic "rule" {
        for_each = application_rule_collection.value.rules

        content {
          name        = rule.value.name
          description = rule.value.description
          dynamic "protocols" {

            for_each = rule.value.protocols

            content {
              type = protocols.value.type
              port = protocols.value.port
            }

          }
          source_addresses      = rule.value.source_addresses
          source_ip_groups      = rule.value.source_ip_groups
          destination_addresses = rule.value.destination_addresses
          destination_fqdns     = rule.value.destination_fqdns
          destination_fqdn_tags = rule.value.destination_fqdn_tags
        }
      }
    }
  }

  dynamic "nat_rule_collection" {

    for_each = each.value.nat_rule_collection

    content {
      name     = nat_rule_collection.value.name
      priority = nat_rule_collection.value.priority
      action   = nat_rule_collection.value.action
      dynamic "rule" {
        for_each = nat_rule_collection.value.rules

        content {
          name                = rule.value.name
          protocols           = rule.value.protocols
          source_addresses    = rule.value.source_addresses
          source_ip_groups    = rule.value.source_ip_groups
          destination_address = rule.value.destination_address
          destination_ports   = rule.value.destination_ports
          translated_address  = rule.value.translated_address
          translated_port     = rule.value.translated_port
        }
      }
    }
  }

  dynamic "network_rule_collection" {

    for_each = each.value.network_rule_collection

    content {
      name     = network_rule_collection.value.name
      priority = network_rule_collection.value.priority
      action   = network_rule_collection.value.action
      dynamic "rule" {
        for_each = network_rule_collection.value.rules

        content {
          name                  = rule.value.name
          protocols             = rule.value.protocols
          source_addresses      = rule.value.source_addresses
          source_ip_groups      = rule.value.source_ip_groups
          destination_addresses = rule.value.destination_addresses
          destination_ip_groups = rule.value.destination_ip_groups
          destination_fqdns     = rule.value.destination_fqdns
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }
}