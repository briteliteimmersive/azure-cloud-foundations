locals {

  bastion_hosts = {
    for subnet_key, subnet in local.subnets : subnet_key => {
      vnet_key               = subnet.vnet_key
      subnet_key             = subnet_key
      sku                    = subnet.bastion_host.sku
      name                   = subnet.bastion_host.name
      bastion_public_ip_name = format("%s-pip", subnet.bastion_host.name)
      bastion_ip_config_name = "BastionPublicIPConfig"
    } if subnet.bastion_host != null
  }

}
resource "azurerm_public_ip" "bastion_host_pip" {
  for_each            = local.bastion_hosts
  name                = each.value.bastion_public_ip_name
  location            = local.location
  resource_group_name = azurerm_virtual_network.virtual_network[each.value.vnet_key].resource_group_name
  allocation_method   = "Static"
  sku                 = each.value.sku
  tags                = azurerm_virtual_network.virtual_network[each.value.vnet_key].tags
}

resource "azurerm_bastion_host" "bastion_host" {
  for_each            = local.bastion_hosts
  name                = each.value.name
  location            = local.location
  resource_group_name = azurerm_virtual_network.virtual_network[each.value.vnet_key].resource_group_name
  sku                 = each.value.sku
  tags                = azurerm_virtual_network.virtual_network[each.value.vnet_key].tags
  ip_configuration {
    name                 = each.value.bastion_ip_config_name
    subnet_id            = azurerm_subnet.subnet[each.value.subnet_key].id
    public_ip_address_id = azurerm_public_ip.bastion_host_pip[each.key].id
  }

}