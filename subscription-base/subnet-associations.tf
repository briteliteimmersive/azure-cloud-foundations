locals {
  route_table_associations = {
    for subnet in local.subnets :
    format("%s-rte-%d", subnet.subnet_key, subnet.route_table_serial_no) => {
      subnet_key      = subnet.subnet_key
      route_table_key = format("rte-%d", subnet.route_table_serial_no)
    }
    if subnet.route_table_serial_no != -100
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
    format("%s-nsg-%d", subnet.subnet_key, subnet.nsg_serial_no) => {
      subnet_key = subnet.subnet_key
      nsg_key    = format("nsg-%d", subnet.nsg_serial_no)
    }
    if subnet.nsg_serial_no != -100
  }
}

resource "azurerm_subnet_network_security_group_association" "app_sub_network_subnet_nsg_associations" {
  for_each                  = local.nsg_associations
  subnet_id                 = azurerm_subnet.subnet[each.value.subnet_key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.value.nsg_key].id
}