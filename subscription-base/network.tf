## Input variables
variable "network_configs" {
  type = object(
    {
      resource_group_name = string
      network_tags        = optional(map(string), {})
      virtual_networks = list(object(
        {
          name          = string
          address_space = list(string)
          dns_servers   = optional(list(string))
          subnets = optional(list(object(
            {
              name                                          = string
              address_prefix                                = string
              service_endpoints                             = optional(list(string))
              private_endpoint_network_policies_enabled     = optional(bool)
              private_link_service_network_policies_enabled = optional(bool)
              associated_nsg_name                           = string
              associated_route_table_name                   = string
              delegation = optional(list(object({
                service_delegation = object({
                  name    = string
                  actions = list(string)
                })
              })))
              bastion_host = optional(object(
                {
                  name = string
                  sku  = string
                }
              ))
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

  virtual_networks = {
    for network in local.network_configs.virtual_networks :
    lower(format("%s/%s", local.network_configs.resource_group_name, network.name)) => merge(network, {
      vnet_key = lower(format("%s/%s", local.network_configs.resource_group_name, network.name))
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

  subnet_list = flatten([
    for vnet_key, vnet in local.virtual_networks :
    [
      for subnet in vnet.subnets :
      merge(subnet, {
        subnet_key = lower(format("%s/%s", vnet_key, subnet.name)),
        vnet_key   = vnet_key
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