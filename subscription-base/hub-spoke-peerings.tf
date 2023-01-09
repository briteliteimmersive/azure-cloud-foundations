## Hub-Spoke peering
locals {

  regional_hub_vnet_id = try(format(
    "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Network/virtualNetworks/%s",
    local.regional_hub_subscription_id,
    local.regional_hub_vnet_resource_group_name,
    local.regional_hub_vnet_name
  ), null)

  spoke_to_hub_peerings = {
    for vnet_key, vnet in local.virtual_networks :
    lower(format("%s-to-%s/%s", vnet_key, local.regional_hub_vnet_resource_group_name, local.regional_hub_vnet_name)) => {
      peering_key = lower(format("%s-to-%s/%s", vnet_key, local.regional_hub_vnet_resource_group_name, local.regional_hub_vnet_name))
      name        = format("%s-to-%s", vnet.name, local.regional_hub_vnet_name)
      vnet_key    = vnet_key
    }
    if local.regional_hub_vnet_id != null
  }

  hub_to_spoke_peerings = {
    for vnet_key, vnet in local.virtual_networks :
    lower(format("%s/%s-to-%s", local.regional_hub_vnet_resource_group_name, local.regional_hub_vnet_name, vnet_key)) => {
      peering_key     = lower(format("%s/%s-to-%s", local.regional_hub_vnet_resource_group_name, local.regional_hub_vnet_name, vnet_key))
      name            = format("%s-to-%s", local.regional_hub_vnet_name, vnet.name)
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