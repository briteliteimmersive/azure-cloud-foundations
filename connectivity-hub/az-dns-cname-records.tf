locals {
  cname_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for cname_record in zone.cname_records : merge(cname_record, {
        cname_record_key = lower(format("%s/%s", zone_key, cname_record.name))
        zone_key         = zone_key
        tags             = merge(cname_record.tags, zone.tags)
      })
    ]
  ])

  cname_records = {
    for cname_record in local.cname_records_list : cname_record.cname_record_key => cname_record
  }
}


resource "azurerm_dns_cname_record" "cname_record" {
  for_each            = local.cname_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl
  record              = each.value.record
  tags                = each.value.tags
}