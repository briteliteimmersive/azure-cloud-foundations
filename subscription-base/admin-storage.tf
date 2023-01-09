locals {
  storage_config = {
    for storage_config in local.admin_storage : lower(format("%s/%s", local.resource_groups.admin_rg.name, storage_config.name)) => merge(storage_config, {
      storage_key = lower(format("%s/%s", local.resource_groups.admin_rg.name, storage_config.name))
      network_rules = {
        default_action = "Deny"
        bypass         = ["Logging", "Metrics", "AzureServices"]
        ip_rules = distinct(concat(
          #   [for ip_range in var.org_public_ip_ranges : replace(replace(ip_range, "/32", ""), "/31", "")],
          [for ip_range in local.admin_network_rules.public_ip_ranges : replace(replace(ip_range, "/32", ""), "/31", "")]
        ))
        virtual_network_subnet_ids = concat(
          local.deployment_agent_subnet_id, ## Required for file share, if not whitelisted gives 403 error.
          local.admin_network_rules.subnet_ids,
          [for subnet_key, subnet in azurerm_subnet.subnet : subnet.id]
        )
      }
    })
  }

  storage_container_list = flatten([
    for storage_key, storage_config in local.storage_config : [
      for container in coalesce(storage_config.containers, []) :
      {
        container_key         = format("%s/%s", storage_key, container.name)
        storage_key           = storage_key
        name                  = container.name
        container_access_type = container.container_access_type
      }
    ]
  ])

  containers = {
    for container in local.storage_container_list : container.container_key => container
  }

  storage_share_list = flatten([
    for storage_key, storage_config in local.storage_config : [
      for file_share in coalesce(storage_config.file_shares, []) : merge(file_share,
        {
          file_share_key = format("%s/%s", storage_key, file_share.name)
          storage_key    = storage_key
      })
    ]
  ])

  storage_shares = {
    for file_share in local.storage_share_list : file_share.file_share_key => file_share
  }
}

resource "azurerm_storage_account" "storage_account" {
  for_each                        = local.storage_config
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.resource_group["admin_rg"].name
  location                        = local.location
  account_tier                    = each.value.account_tier
  account_kind                    = each.value.account_kind
  access_tier                     = each.value.access_tier
  account_replication_type        = each.value.account_replication_type
  edge_zone                       = each.value.edge_zone
  enable_https_traffic_only       = true
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  infrastructure_encryption_enabled = true

  dynamic "blob_properties" {
    for_each = try(length(each.value.blob_properties), 0) > 0 ? [each.value.blob_properties] : []
    content {
      versioning_enabled  = blob_properties.value.versioning_enabled
      change_feed_enabled = blob_properties.value.change_feed_enabled

      dynamic "container_delete_retention_policy" {
        for_each = try(length(blob_properties.value.container_delete_retention_policy), 0) > 0 ? [blob_properties.value.container_delete_retention_policy] : []

        content {
          days = container_delete_retention_policy.value.days
        }
      }

      dynamic "delete_retention_policy" {
        for_each = try(length(blob_properties.value.delete_retention_policy), 0) > 0 ? [blob_properties.value.delete_retention_policy] : []

        content {
          days = delete_retention_policy.value.days
        }
      }
    }
  }

  dynamic "network_rules" {
    for_each = each.value.network_rules != null ? [each.value.network_rules] : []
    content {
      default_action             = network_rules.value.default_action
      bypass                     = network_rules.value.bypass
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
    }
  }

  tags = azurerm_resource_group.resource_group["admin_rg"].tags

}


resource "azurerm_storage_container" "container" {
  for_each              = local.containers
  name                  = each.value.name
  storage_account_name  = azurerm_storage_account.storage_account[each.value.storage_key].name
  container_access_type = each.value.container_access_type
}


resource "azurerm_storage_share" "storage_share" {
  for_each             = local.storage_shares
  name                 = each.value.name
  storage_account_name = azurerm_storage_account.storage_account[each.value.storage_key].name
  quota                = each.value.quota
}