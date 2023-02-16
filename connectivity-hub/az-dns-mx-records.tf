locals {
  mx_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for mx_record in zone.mx_records : merge(mx_record, {
        mx_record_key = lower(format("%s/%s", zone_key, mx_record.name))
        zone_key      = zone_key
        tags          = merge(mx_record.tags, zone.tags)
      })
    ]
  ])

  mx_records = {
    for mx_record in local.mx_records_list : mx_record.mx_record_key => mx_record
  }
}


resource "azurerm_dns_mx_record" "mx_record" {
  for_each            = local.mx_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.record

    content {
      preference = record.value.preference
      exchange   = record.value.exchange
    }
  }
  tags = each.value.tags
}