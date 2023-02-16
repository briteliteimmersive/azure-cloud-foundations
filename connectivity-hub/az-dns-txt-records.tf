locals {
  txt_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for txt_record in zone.txt_records : merge(txt_record, {
        txt_record_key = lower(format("%s/%s", zone_key, txt_record.name))
        zone_key       = zone_key
        tags           = merge(txt_record.tags, zone.tags)
      })
    ]
  ])

  txt_records = {
    for txt_record in local.txt_records_list : txt_record.txt_record_key => txt_record
  }
}


resource "azurerm_dns_txt_record" "txt_record" {
  for_each            = local.txt_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.record

    content {
      value = record.value.value
    }
  }
  tags = each.value.tags
}