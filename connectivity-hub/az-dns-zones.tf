variable "dns_zones" {
  type = list(object(
    {
      name                = string
      resource_group_name = optional(string)
      soa_record = optional(object(
        {
          email         = string
          host_name     = string
          expire_time   = optional(number)
          minimum_ttl   = optional(number)
          refresh_time  = optional(number)
          retry_time    = optional(number)
          serial_number = optional(number)
          ttl           = optional(number)
          tags          = optional(map(string), {})
        }
      ))
      a_records = optional(list(object(
        {
          name    = string
          ttl     = number
          records = list(string)
          tags    = optional(map(string), {})
        }
      )), [])
      aaaa_records = optional(list(object(
        {
          name    = string
          ttl     = number
          records = list(string)
          tags    = optional(map(string), {})
        }
      )), [])
      caa_records = optional(list(object(
        {
          name = string
          ttl  = number
          record = list(object(
            {
              flags = number
              tag   = string
              value = string
            }
          ))
          tags = optional(map(string), {})
        }
      )), [])
      cname_records = optional(list(object(
        {
          name   = string
          ttl    = number
          record = string
          tags   = optional(map(string), {})
        }
      )), [])
      mx_records = optional(list(object(
        {
          name = string
          ttl  = number
          record = list(object(
            {
              preference = number
              exchange   = string
            }
          ))
          tags = optional(map(string), {})
        }
      )), [])
      ns_records = optional(list(object(
        {
          name    = string
          ttl     = number
          records = list(string)
          tags    = optional(map(string), {})
        }
      )), [])
      ptr_records = optional(list(object(
        {
          name    = string
          ttl     = number
          records = list(string)
          tags    = optional(map(string), {})
        }
      )), [])
      srv_records = optional(list(object(
        {
          name = string
          ttl  = number
          record = list(object(
            {
              priority = number
              weight   = number
              port     = number
              target   = string
            }
          ))
          tags = optional(map(string), {})
        }
      )), [])
      txt_records = optional(list(object(
        {
          name = string
          ttl  = number
          record = list(object(
            {
              value = string
            }
          ))
          tags = optional(map(string), {})
        }
      )), [])
      tags = optional(map(string), {})
    }
  ))

  default = []
}

locals {
  dns_zones_input = var.dns_zones

  dns_zone_resource_group_list = distinct([
    for zone in local.dns_zones_input : {
      name         = zone.resource_group_name
      resource_key = lower(zone.resource_group_name)
      location     = local.location
      tags         = local.common_resource_tags
    } if zone.resource_group_name != null
  ])

  dns_zone_resource_groups = {
    for zone_rg in local.dns_zone_resource_group_list : zone_rg.resource_key => zone_rg
  }

  dns_zones = {
    for zone in local.dns_zones_input : lower(format("%s/%s", coalesce(zone.resource_group_name, local.vnet_resource_group_name), zone.name)) => merge(zone, {
      resource_group_key = lower(coalesce(zone.resource_group_name, local.vnet_resource_group_name))
      tags               = merge(zone.tags, local.common_resource_tags)
    })
  }
}

resource "azurerm_resource_group" "dns_zone_resource_grp" {
  for_each = local.dns_zone_resource_groups
  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags
}

resource "time_sleep" "wait_seconds" {
  for_each        = local.dns_zone_resource_groups
  depends_on      = [azurerm_resource_group.dns_zone_resource_grp]
  create_duration = "5s"
}

resource "azurerm_dns_zone" "public_dns_zone" {
  for_each            = local.dns_zones
  name                = each.value.name
  resource_group_name = each.value.resource_group_name != null ? azurerm_resource_group.dns_zone_resource_grp[each.value.resource_group_key].name : local.vnet_resource_group_name

  dynamic "soa_record" {
    for_each = try(length(each.value.soa_record) > 0, false) ? [merge(each.value.soa_record, {
      tags = merge(each.value.soa_record.tags, each.value.tags)
    })] : []

    content {
      email         = soa_record.value.email
      host_name     = soa_record.value.host_name
      expire_time   = soa_record.value.expire_time
      minimum_ttl   = soa_record.value.minimum_ttl
      refresh_time  = soa_record.value.refresh_time
      retry_time    = soa_record.value.retry_time
      serial_number = soa_record.value.serial_number
      ttl           = soa_record.value.ttl
      tags          = each.value.tags
    }
  }

  tags = each.value.tags
}