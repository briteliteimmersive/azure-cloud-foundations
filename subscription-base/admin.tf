## Input variables
variable "admin_configs" {
  type = object(
    {
      resource_group_name = string
      admin_tags          = optional(map(string))
      network_rules = optional(object({
        public_ip_ranges = list(string)
        subnet_ids       = list(string)
        }), {
        public_ip_ranges = []
        subnet_ids       = []
      })
      storage_accounts = list(object(
        {
          name                     = string
          account_kind             = optional(string, "StorageV2")
          account_tier             = optional(string, "Standard")
          account_replication_type = optional(string, "LRS")
          access_tier              = optional(string)
          edge_zone                = optional(string)
          blob_properties = optional(object(
            {
              versioning_enabled  = bool
              change_feed_enabled = bool
              container_delete_retention_policy = object(
                {
                  days = number
                }
              )
              delete_retention_policy = object(
                {
                  days = number
                }
              )
            }
            ), {
            versioning_enabled  = true
            change_feed_enabled = null
            container_delete_retention_policy = {
              days = 30
            }
            delete_retention_policy = {
              days = 30
            }
          })
          containers = optional(list(object({
            name                  = string
            container_access_type = optional(string, "private")
          })))
          file_shares = optional(list(object(
            {
              name  = string
              quota = number
            }
          )))
        }
      ))
      keyvault = object(
        {
          name     = string
          sku_name = string
        }
      )
      disk_encryption_sets = list(object(
        {
          name     = string
          key_name = string
        }
      ))
      recovery_services_vault = object(
        {
          name = string
          sku  = string
          vm_backup_policies = optional(list(object(
            {
              name     = string
              timezone = string
              backup = object({
                frequency = string
                time      = string
              })
              retention_daily = object({
                count = number
              })
              retention_weekly = optional(object({
                count    = number
                weekdays = list(string)
              }))
              retention_monthly = optional(object({
                count    = number
                weekdays = list(string)
                weeks    = list(string)
              }))
              retention_yearly = optional(object({
                count    = number
                weekdays = list(string)
                weeks    = list(string)
                months   = list(string)
              }))
            }
          )), [])
          fileshare_backup_policies = optional(list(object(
            {
              name     = string
              timezone = string
              backup = object({
                frequency = string
                time      = string
              })
              retention_daily = object({
                count = number
              })
              retention_weekly = optional(object({
                count    = number
                weekdays = list(string)
              }))
              retention_monthly = optional(object({
                count    = number
                weekdays = list(string)
                weeks    = list(string)
              }))
              retention_yearly = optional(object({
                count    = number
                weekdays = list(string)
                weeks    = list(string)
                months   = list(string)
              }))
            }
          )), [])
        }
      )
    }
  )
}

## Run-time variables
locals {

  admin_configs         = var.admin_configs
  admin_network_rules   = var.admin_configs.network_rules
  admin_storage         = var.admin_configs.storage_accounts
  admin_keyvault        = var.admin_configs.keyvault
  admin_disk_encryption = var.admin_configs.disk_encryption_sets
  admin_recovery_vault  = var.admin_configs.recovery_services_vault

}