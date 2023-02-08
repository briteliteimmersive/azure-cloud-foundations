## Disk Encryption Set
locals {
  disk_encryption_config = {
    for disk_encryption_config in local.admin_disk_encryption : lower(format("%s/%s", local.resource_groups.admin_rg.name, disk_encryption_config.name)) => merge(disk_encryption_config, {
      key_type = "RSA"
      key_size = 2048
      key_opts = [
        "decrypt",
        "encrypt",
        "sign",
        "unwrapKey",
        "verify",
        "wrapKey",
      ]
      disk_encryption_set_key = lower(format("%s/%s", local.resource_groups.admin_rg.name, disk_encryption_config.name))
      keyvault_key            = local.admin_keyvault_key
    })
  }
}

resource "azurerm_key_vault_key" "keyvault_key" {
  for_each     = local.disk_encryption_config
  name         = each.value.key_name
  key_vault_id = azurerm_key_vault.admin_keyvault[each.value.keyvault_key].id
  key_type     = each.value.key_type
  key_size     = each.value.key_size
  key_opts     = each.value.key_opts
  depends_on = [
    azurerm_role_assignment.kv_admin_role_assignment
  ]
}

resource "azurerm_disk_encryption_set" "disk_encryption_set" {
  for_each            = local.disk_encryption_config
  name                = each.value.name
  location            = local.location
  resource_group_name = azurerm_resource_group.resource_group["admin_rg"].name
  key_vault_key_id    = azurerm_key_vault_key.keyvault_key[each.key].id
  tags                = azurerm_resource_group.resource_group["admin_rg"].tags

  identity {
    type = "SystemAssigned" ## Only SystemAssigned is supported
  }
}

data "azurerm_role_definition" "kv_cypto_user_builtin_role" {
  name = "Key Vault Crypto Service Encryption User"
}

resource "azurerm_role_assignment" "disk_encryption_role_assignment" {
  for_each           = local.disk_encryption_config
  scope              = azurerm_key_vault.admin_keyvault[each.value.keyvault_key].id
  role_definition_id = format("/subscriptions/%s%s", local.subscription_id, data.azurerm_role_definition.kv_cypto_user_builtin_role.id)
  principal_id       = azurerm_disk_encryption_set.disk_encryption_set[each.key].identity.0.principal_id
}