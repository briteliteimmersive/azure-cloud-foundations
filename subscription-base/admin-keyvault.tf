## Create a key vault
locals {
  admin_keyvault_key = lower(format("%s/%s", local.resource_groups.admin_rg.name, local.admin_keyvault.name))
  keyvault_config = {
    "${local.admin_keyvault_key}" = {
      keyvault_key = local.admin_keyvault_key
      name         = local.admin_keyvault.name
      sku_name     = local.admin_keyvault.sku_name
      network_acls = {
        bypass = "AzureServices"
        ## Cannot be set to deny unless deployment agent information is passed in.
        default_action = length(local.deployment_agent_subnet_id) > 0 ? "Deny" : "Allow"
        ip_rules = distinct(concat(
          # var.org_public_ip_ranges, 
          local.admin_network_rules.public_ip_ranges
        ))
        virtual_network_subnet_ids = concat(
          local.deployment_agent_subnet_id,
          local.admin_network_rules.subnet_ids,
          [for subnet_key, subnet in azurerm_subnet.subnet : subnet.id]
        )
      }
    }
  }
}

resource "azurerm_key_vault" "admin_keyvault" {
  for_each                  = local.keyvault_config
  name                      = each.value.name
  location                  = local.location
  resource_group_name       = azurerm_resource_group.resource_group["admin_rg"].name
  sku_name                  = each.value.sku_name
  tenant_id                 = local.client_tenant_id
  purge_protection_enabled  = true
  enable_rbac_authorization = true
  network_acls {
    bypass                     = each.value.network_acls.bypass
    default_action             = each.value.network_acls.default_action
    ip_rules                   = each.value.network_acls.ip_rules
    virtual_network_subnet_ids = each.value.network_acls.virtual_network_subnet_ids
  }
  tags = azurerm_resource_group.resource_group["admin_rg"].tags
}

data "azurerm_role_definition" "kv_admin_builtin_role" {
  name = "Key Vault Administrator"
}

resource "azurerm_role_assignment" "kv_admin_role_assignment" {
  ## Key Vault Admin access to self
  for_each           = local.keyvault_config
  scope              = azurerm_key_vault.admin_keyvault[each.key].id
  role_definition_id = format("/subscriptions/%s%s", local.subscription_id, data.azurerm_role_definition.kv_admin_builtin_role.id)
  principal_id       = local.client_object_id
}

resource "time_sleep" "role_assignment_propagation" {
  for_each        = local.keyvault_config
  create_duration = "15s"

  triggers = {
    role_assignment_id = azurerm_role_assignment.kv_admin_role_assignment[each.key].id
  }
}

data "azurerm_role_definition" "kv_crypto_officer_builtin_role" {
  name = "Key Vault Crypto Officer"
}

resource "azurerm_role_assignment" "infra_kv_sub_spn_assignment" {
  for_each           = local.sub_spn_role_assignments
  scope              = azurerm_key_vault.admin_keyvault[local.admin_keyvault_key].id
  role_definition_id = format("/subscriptions/%s%s", local.subscription_id, data.azurerm_role_definition.kv_crypto_officer_builtin_role.id)
  principal_id       = azuread_service_principal.sub_app_spn[each.key].object_id
}