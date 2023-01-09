## Input variables
variable "route_table_configs" {
  type = list(object(
    {
      name                          = string
      disable_bgp_route_propagation = optional(bool)
      routes = optional(list(object({
        name                   = string
        address_prefix         = string
        next_hop_type          = string
        next_hop_in_ip_address = string
      })))
    }
  ))

}

## Run-time variables
locals {

  route_tables = {
    for route_table in var.route_table_configs :
    lower(format("%s/%s", local.resource_groups.network_rg.name, route_table.name)) => merge(route_table, {
      route_table_key = lower(format("%s/%s", local.resource_groups.network_rg.name, route_table.name))
    })
  }

  route_table_keys_by_name = {
    for route_table_key, route_table in local.route_tables : route_table.name => route_table_key
  }

}

resource "azurerm_route_table" "route_table" {
  for_each                      = local.route_tables
  name                          = each.value.name
  location                      = local.location
  resource_group_name           = azurerm_resource_group.resource_group["network_rg"].name
  tags                          = azurerm_resource_group.resource_group["network_rg"].tags
  disable_bgp_route_propagation = each.value.disable_bgp_route_propagation
}

## Create routes
locals {
  route_list = flatten(
    [
      for udr_key, udr in local.route_tables : [
        for route in coalesce(udr.routes, []) : merge(route,
          {
            udr_key       = udr_key
            udr_route_key = format("%s/%s", udr_key, route.name)
          }
        )
      ]
    ]
  )

  routes = {
    for route in local.route_list : route.udr_route_key => route
  }
}

resource "azurerm_route" "routes" {
  for_each               = local.routes
  name                   = each.value.name
  resource_group_name    = azurerm_resource_group.resource_group["network_rg"].name
  route_table_name       = azurerm_route_table.route_table[each.value.udr_key].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}