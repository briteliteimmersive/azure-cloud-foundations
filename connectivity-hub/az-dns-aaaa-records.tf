locals {
  aaaa_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for aaaa_record in zone.aaaa_records : merge(aaaa_record, {
        aaaa_record_key = lower(format("%s/%s", zone_key, aaaa_record.name))
        zone_key        = zone_key
        tags            = merge(aaaa_record.tags, zone.tags)
      })
    ]
  ])

  aaaa_records = {
    for aaaa_record in local.aaaa_records_list : aaaa_record.aaaa_record_key => aaaa_record
  }
}


resource "azurerm_dns_aaaa_record" "aaaa_record" {
  for_each            = local.aaaa_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = each.value.tags
}