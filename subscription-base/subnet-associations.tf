locals {
  route_table_associations = {
    for subnet in local.subnets :
    lower(format("%s/%s", subnet.subnet_key, subnet.associated_route_table_name)) => {
      subnet_key      = subnet.subnet_key
      association_key = lower(format("%s/%s", subnet.subnet_key, subnet.associated_route_table_name))
      route_table_key = local.route_table_keys_by_name[subnet.associated_route_table_name]
    }
    if subnet.associated_route_table_name != null
  }
}

resource "azurerm_subnet_route_table_association" "subnet_udr_association" {
  for_each       = local.route_table_associations
  subnet_id      = azurerm_subnet.subnet[each.value.subnet_key].id
  route_table_id = azurerm_route_table.route_table[each.value.route_table_key].id
}

locals {
  nsg_associations = {
    for subnet in local.subnets :
    lower(format("%s/%s", subnet.subnet_key, subnet.associated_nsg_name)) => {
      subnet_key      = subnet.subnet_key
      association_key = lower(format("%s/%s", subnet.subnet_key, subnet.associated_nsg_name))
      nsg_key         = local.nsg_keys_by_name[subnet.associated_nsg_name]
    }
    if subnet.associated_nsg_name != null
  }
}

resource "azurerm_subnet_network_security_group_association" "app_sub_network_subnet_nsg_associations" {
  for_each                  = local.nsg_associations
  subnet_id                 = azurerm_subnet.subnet[each.value.subnet_key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.value.nsg_key].id
}