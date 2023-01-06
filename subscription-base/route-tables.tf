## Input variables
variable "route_table_configs" {
  type = list(object(
    {
      serial_no                     = number
      environment                   = optional(string)
      name                          = optional(string)
      disable_bgp_route_propagation = optional(bool)
      routes = optional(list(object({
        route_name             = string
        address_prefix         = string
        next_hop_type          = string
        next_hop_in_ip_address = string
      })))
    }
  ))

}

## Run-time variables
locals {

  ## Example = "OZI-GX-NP-SUB001-WE-RTE-COPS-N001"
  route_table_naming_format = "%s-%s-rte-%s-%s%03d"

  route_tables = {
    for route_table in var.route_table_configs :
    lower(format("rte-%d", route_table.serial_no)) => merge(route_table, {
      resource_key = lower(format("rte-%d", route_table.serial_no))
      name = lower(coalesce(route_table.name, format(
        local.route_table_naming_format,
        local.subscription_name,
        local.az_location_code,
        local.app_unique_code,
        try(lookup(local.env_code_map, route_table.environment), local.infra_env_code),
        route_table.serial_no
      )))
    })
  }

  #   route_table_list = flatten([
  #     for vnet_key, vnet in local.virtual_networks : [
  #       for route_table in coalesce(vnet.route_tables, []) : merge(route_table, {
  #         vnet_key = vnet_key
  #         route_table_key = lower(format(
  #           "%s-rte-%s%d",
  #           vnet_key,
  #           try(lookup(local.env_code_map, route_table.route_table_environment), local.infra_env_code),
  #           route_table.route_table_serial_no
  #         ))
  #         name = lower(coalesce(route_table.route_table_name, format(
  #           local.route_table_naming_format,
  #           local.subscription_name,
  #           local.az_location_code,
  #           local.app_unique_code,
  #           try(lookup(local.env_code_map, route_table.route_table_environment), local.infra_env_code),
  #           route_table.route_table_serial_no
  #         )))
  #       })
  #     ]
  #   ])

  #   route_tables = {
  #     for route_table in local.route_table_list : route_table.route_table_key => route_table
  #   }
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
            udr_route_key = "${udr_key}-${route.route_name}"
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
  name                   = each.value.route_name
  resource_group_name    = azurerm_resource_group.resource_group["network_rg"].name
  route_table_name       = azurerm_route_table.route_table[each.value.udr_key].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}