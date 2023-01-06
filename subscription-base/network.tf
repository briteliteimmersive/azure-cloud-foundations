## Input variables
variable "network_configs" {
  type = object(
    {
      resource_group_name = optional(string)
      network_tags        = optional(map(string), {})
      regional_hub = optional(object(
        {
          subscription_id          = string
          vnet_name                = string
          vnet_resource_group_name = string
        }
      ))
      virtual_networks = list(object(
        {
          serial_no     = number
          environment   = optional(string)
          name          = optional(string)
          address_space = list(string)
          dns_servers   = optional(list(string))
          subnets = optional(list(object(
            {
              serial_no                                     = number
              environment                                   = optional(string)
              app_unique_code                               = optional(string)
              name                                          = optional(string)
              address_prefix                                = string
              service_endpoints                             = optional(list(string))
              private_endpoint_network_policies_enabled     = optional(bool)
              private_link_service_network_policies_enabled = optional(bool)
              nsg_serial_no                                 = optional(number, -100)
              route_table_serial_no                         = optional(number, -100)
              delegation = optional(list(object({
                service_delegation = object({
                  name    = string
                  actions = list(string)
                })
              })))
            }
          )))
        }
      ))
    }
  )

}

## Run-time variables
locals {

  network_configs = var.network_configs

  ## Example = "OZI-GX-NP-SUB001-WE-VNT-N001"
  vnet_naming_format = "%s-%s-vnt-%s%03d"

  virtual_networks = {
    for network in local.network_configs.virtual_networks :
    lower(format("vnet-%d", network.serial_no)) => merge(network, {
      resource_key = lower(format("vnet-%d", network.serial_no))
      name = lower(coalesce(network.name, format(
        local.vnet_naming_format,
        local.subscription_name,
        local.az_location_code,
        try(lookup(local.env_code_map, network.environment), local.infra_env_code),
        network.serial_no
      )))
    })
  }
}

## Create Virtual Network
resource "azurerm_virtual_network" "virtual_network" {
  for_each            = local.virtual_networks
  name                = each.value.name
  location            = local.location
  resource_group_name = azurerm_resource_group.resource_group["network_rg"].name
  address_space       = each.value.address_space
  dns_servers         = each.value.dns_servers
  tags                = azurerm_resource_group.resource_group["network_rg"].tags
}

locals {

  ## Example = "OZI-GX-NP-SUB013-WE-SNT-ONEC-S001" 
  subnet_naming_format = "%s-%s-snt-%s-%s%03d"

  subnet_list = flatten([
    for vnet_key, vnet in local.virtual_networks :
    [
      for subnet in vnet.subnets :
      merge(subnet, {
        subnet_key = lower(format("snt-%d", subnet.serial_no)),
        vnet_key   = vnet_key
        name = lower(coalesce(subnet.name, format(
          local.subnet_naming_format,
          local.subscription_name,
          local.az_location_code,
          coalesce(subnet.app_unique_code, local.app_unique_code),
          try(lookup(local.env_code_map, subnet.environment), local.infra_env_code),
          subnet.serial_no
        )))
  })]])

  subnets = { for subnet in local.subnet_list : subnet.subnet_key => subnet }
}

resource "azurerm_subnet" "subnet" {
  for_each                                      = local.subnets
  name                                          = each.value.name
  resource_group_name                           = azurerm_virtual_network.virtual_network[each.value.vnet_key].resource_group_name
  virtual_network_name                          = azurerm_virtual_network.virtual_network[each.value.vnet_key].name
  address_prefixes                              = [each.value.address_prefix]
  service_endpoints                             = each.value.service_endpoints
  private_endpoint_network_policies_enabled     = each.value.private_endpoint_network_policies_enabled
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled

  dynamic "delegation" {
    for_each = coalesce(each.value.delegation, [])
    content {
      name = replace(delegation.value.service_delegation.name, "/", ".")
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

## Hub-Spoke peering
locals {
  regional_hub_subscription_id          = try(local.network_configs.regional_hub.subscription_id, null)
  regional_hub_vnet_name                = try(local.network_configs.regional_hub.vnet_name, null)
  regional_hub_vnet_resource_group_name = try(local.network_configs.regional_hub.vnet_resource_group_name, null)

  regional_hub_vnet_id = try(format(
    "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Network/virtualNetworks/%s",
    local.regional_hub_subscription_id,
    local.regional_hub_vnet_resource_group_name,
    local.regional_hub_vnet_name
  ), null)

  spoke_to_hub_peerings = {
    for vnet_key, vnet in local.virtual_networks :
    lower(format("%s-to-%s", vnet.name, local.regional_hub_vnet_name)) => {
      peering_key = lower(format("%s-to-%s", vnet.name, local.regional_hub_vnet_name))
      name        = lower(format("%s-to-%s", vnet.name, local.regional_hub_vnet_name))
      vnet_key    = vnet_key
    }
    if local.regional_hub_vnet_id != null
  }

  hub_to_spoke_peerings = {
    for vnet_key, vnet in local.virtual_networks :
    lower(format("%s-to-%s", local.regional_hub_vnet_name, vnet.name)) => {
      peering_key     = lower(format("%s-to-%s", local.regional_hub_vnet_name, vnet.name))
      name            = lower(format("%s-to-%s", local.regional_hub_vnet_name, vnet.name))
      remote_vnet_key = vnet_key
    }
    if local.regional_hub_vnet_id != null
  }
}

## Create VNet peering to hub
resource "azurerm_virtual_network_peering" "spoke_to_hub_peerings" {
  for_each                     = local.spoke_to_hub_peerings
  name                         = each.value.name
  resource_group_name          = azurerm_virtual_network.virtual_network[each.value.vnet_key].resource_group_name
  virtual_network_name         = azurerm_virtual_network.virtual_network[each.value.vnet_key].name
  remote_virtual_network_id    = local.regional_hub_vnet_id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke_peerings" {
  for_each                     = local.hub_to_spoke_peerings
  provider                     = azurerm.hub-sub
  name                         = each.key
  resource_group_name          = local.regional_hub_vnet_resource_group_name
  virtual_network_name         = local.regional_hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.virtual_network[each.value.remote_vnet_key].id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
  use_remote_gateways          = false
}