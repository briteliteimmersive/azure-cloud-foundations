locals {
  ptr_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for ptr_record in zone.ptr_records : merge(ptr_record, {
        ptr_record_key = lower(format("%s/%s", zone_key, ptr_record.name))
        zone_key       = zone_key
        tags           = merge(ptr_record.tags, zone.tags)
      })
    ]
  ])

  ptr_records = {
    for ptr_record in local.ptr_records_list : ptr_record.ptr_record_key => ptr_record
  }
}


resource "azurerm_dns_ptr_record" "ptr_record" {
  for_each            = local.ptr_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = each.value.tags
}