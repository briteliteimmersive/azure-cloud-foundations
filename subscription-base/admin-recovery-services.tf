locals {
  recovery_services_vault_config = {
    lower(format("%s/%s", local.resource_groups.admin_rg.name, local.admin_recovery_vault.name)) = merge(local.admin_recovery_vault, {
      recovery_vault_key  = lower(format("%s/%s", local.resource_groups.admin_rg.name, local.admin_recovery_vault.name))
      soft_delete_enabled = false
    })
  }
}

## Create a recovery service vault
resource "azurerm_recovery_services_vault" "admin_recovery_vault" {
  for_each            = local.recovery_services_vault_config
  name                = each.value.name
  location            = local.location
  resource_group_name = azurerm_resource_group.resource_group["admin_rg"].name
  sku                 = each.value.sku
  soft_delete_enabled = each.value.soft_delete_enabled
  tags                = azurerm_resource_group.resource_group["admin_rg"].tags
}

## Backup Policy VMs and Fileshares
locals {

  vm_backup_policy_list = flatten([
    for recovery_vault_key, recovery_services_vault_config in local.recovery_services_vault_config : [
      for policy in coalesce(recovery_services_vault_config.vm_backup_policies, []) :
      merge(policy, {
        recovery_vault_key = recovery_vault_key
        backup_policy_key  = format("%s/%s", recovery_vault_key, recovery_services_vault_config.name)
      })
    ]
  ])

  vm_backup_policies = {
    for policy in local.vm_backup_policy_list : policy.backup_policy_key => policy
  }

  fileshare_backup_policy_list = flatten([
    for recovery_vault_key, recovery_services_vault_config in local.recovery_services_vault_config : [
      for policy in coalesce(recovery_services_vault_config.fileshare_backup_policies, []) :
      merge(policy, {
        recovery_vault_key = recovery_vault_key
        backup_policy_key  = format("%s/%s", recovery_vault_key, recovery_services_vault_config.name)
      })
    ]
  ])

  fileshare_backup_policies = {
    for policy in local.fileshare_backup_policy_list : policy.backup_policy_key => policy
  }
}

resource "azurerm_backup_policy_vm" "backup_policy_vm" {
  for_each            = local.vm_backup_policies
  name                = each.value.name
  resource_group_name = azurerm_resource_group.resource_group["admin_rg"].name
  recovery_vault_name = azurerm_recovery_services_vault.admin_recovery_vault[each.value.recovery_vault_key].name

  timezone = each.value.timezone

  backup {
    frequency = each.value.backup.frequency
    time      = each.value.backup.time
  }
  dynamic "retention_daily" {
    for_each = [each.value.retention_daily]
    content {
      count = retention_daily.value.count
    }
  }
  dynamic "retention_weekly" {
    for_each = try(length(each.value.retention_weekly), 0) > 0 ? [each.value.retention_weekly] : []
    content {
      count    = retention_weekly.value.count
      weekdays = retention_weekly.value.weekdays
    }
  }
  dynamic "retention_monthly" {
    for_each = try(length(each.value.retention_monthly), 0) > 0 ? [each.value.retention_monthly] : []
    content {
      count    = retention_monthly.value.count
      weekdays = retention_monthly.value.weekdays
      weeks    = retention_monthly.value.weeks
    }
  }
  dynamic "retention_yearly" {
    for_each = try(length(each.value.retention_yearly), 0) > 0 ? [each.value.retention_yearly] : []
    content {
      count    = retention_yearly.value.count
      weekdays = retention_yearly.value.weekdays
      weeks    = retention_yearly.value.weeks
      months   = retention_yearly.value.months
    }
  }
}

resource "azurerm_backup_policy_file_share" "backup_policy_fileshare" {
  for_each            = local.fileshare_backup_policies
  name                = each.value.name
  resource_group_name = azurerm_resource_group.resource_group["admin_rg"].name
  recovery_vault_name = azurerm_recovery_services_vault.admin_recovery_vault[each.value.recovery_vault_key].name

  timezone = each.value.timezone

  backup {
    frequency = each.value.backup.frequency
    time      = each.value.backup.time
  }
  dynamic "retention_daily" {
    for_each = [each.value.retention_daily]
    content {
      count = retention_daily.value.count
    }
  }
  dynamic "retention_weekly" {
    for_each = try(length(each.value.retention_weekly), 0) > 0 ? [each.value.retention_weekly] : []
    content {
      count    = retention_weekly.value.count
      weekdays = retention_weekly.value.weekdays
    }
  }
  dynamic "retention_monthly" {
    for_each = try(length(each.value.retention_monthly), 0) > 0 ? [each.value.retention_monthly] : []
    content {
      count    = retention_monthly.value.count
      weekdays = retention_monthly.value.weekdays
      weeks    = retention_monthly.value.weeks
    }
  }
  dynamic "retention_yearly" {
    for_each = try(length(each.value.retention_yearly), 0) > 0 ? [each.value.retention_yearly] : []
    content {
      count    = retention_yearly.value.count
      weekdays = retention_yearly.value.weekdays
      weeks    = retention_yearly.value.weeks
      months   = retention_yearly.value.months
    }
  }
}