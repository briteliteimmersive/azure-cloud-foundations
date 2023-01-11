## Input variables
variable "firewall_config" {
    type = object({
        name = string
        resource_group_name = string
        sku_tier = string
        sku_name = string
        vnet_name = string
        vnet_resource_group_name = string
        subnet_name = optional(string, "AzureFirewallSubnet")
        ip_configs = optional(list(object(
            {
                name = string
            }
        )), [
            {
                name = "FWPublicIPConfiguration"
            }
        ])
        tags = optional(map(string), {})
    })
}

locals {

    firewall_config = var.firewall_config
  
  firewall = {
    lower(format("%s/%s", var.firewall_config.resource_group_name, var.firewall_config.name)) = merge(var.firewall_config, {
        firewall_key = lower(format("%s/%s", var.firewall_config.resource_group_name, var.firewall_config.name))
    })
  }

  firewall_public_ips = {
    for fw_key, fw in local.firewall: fw_key => {
        for ip_config in fw.ip_configs: "public_ip_name" => format("%s-pip%d", fw.name, index(fw.ip_configs, ip_config) + 1)
    }
  }
}

data "azurerm_subnet" "fw_subnet" {
  name                 = local.firewall_config.subnet_name
  virtual_network_name = local.firewall_config.vnet_name
  resource_group_name  = local.firewall_config.vnet_resource_group_name
}


resource "azurerm_public_ip" "firewall_pip" {
    for_each = local.firewall_public_ips
  name                = each.value.public_ip_name
  location            = local.location
  resource_group_name = azurerm_resource_group.resource_group["fw_rgp"].name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "firewall" {
    for_each = local.firewall
  name                = each.value.name
  location            = local.location
  resource_group_name = azurerm_resource_group.resource_group[each.value.resource_group_name].name
  sku_name            = each.value.sku_name
  sku_tier            = each.value.sku_tier

  dynamic "ip_configuration" {
    for_each = each.value.ip_configs
    content {
        name                 = ip_configuration.value.name
        subnet_id            = data.azurerm_subnet.fw_subnet.id
        public_ip_address_id = azurerm_public_ip.firewall_pip[each.key].id 
    }
  }
}