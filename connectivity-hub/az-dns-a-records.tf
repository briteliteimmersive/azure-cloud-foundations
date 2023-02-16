locals {
  a_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for a_record in zone.a_records : merge(a_record, {
        a_record_key = lower(format("%s/%s", zone_key, a_record.name))
        zone_key     = zone_key
        tags         = merge(a_record.tags, zone.tags)
      })
    ]
  ])

  a_records = {
    for a_record in local.a_records_list : a_record.a_record_key => a_record
  }
}


resource "azurerm_dns_a_record" "a_record" {
  for_each            = local.a_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = each.value.tags
}