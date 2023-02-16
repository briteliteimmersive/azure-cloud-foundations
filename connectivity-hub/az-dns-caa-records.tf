locals {
  caa_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for caa_record in zone.caa_records : merge(caa_record, {
        caa_record_key = lower(format("%s/%s", zone_key, caa_record.name))
        zone_key       = zone_key
        tags           = merge(caa_record.tags, zone.tags)
      })
    ]
  ])

  caa_records = {
    for caa_record in local.caa_records_list : caa_record.caa_record_key => caa_record
  }
}


resource "azurerm_dns_caa_record" "caa_record" {
  for_each            = local.caa_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.record

    content {
      flags = record.value.flags
      tag   = record.value.tag
      value = record.value.value
    }
  }
  tags = each.value.tags
}