locals {
  ns_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for ns_record in zone.ns_records : merge(ns_record, {
        ns_record_key = lower(format("%s/%s", zone_key, ns_record.name))
        zone_key      = zone_key
        tags          = merge(ns_record.tags, zone.tags)
      })
    ]
  ])

  ns_records = {
    for ns_record in local.ns_records_list : ns_record.ns_record_key => ns_record
  }
}


resource "azurerm_dns_ns_record" "ns_record" {
  for_each            = local.ns_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = each.value.tags
}