locals {
  srv_records_list = flatten([
    for zone_key, zone in local.dns_zones : [
      for srv_record in zone.srv_records : merge(srv_record, {
        srv_record_key = lower(format("%s/%s", zone_key, srv_record.name))
        zone_key       = zone_key
        tags           = merge(srv_record.tags, zone.tags)
      })
    ]
  ])

  srv_records = {
    for srv_record in local.srv_records_list : srv_record.srv_record_key => srv_record
  }
}


resource "azurerm_dns_srv_record" "srv_record" {
  for_each            = local.srv_records
  name                = each.value.name
  zone_name           = azurerm_dns_zone.public_dns_zone[each.value.zone_key].name
  resource_group_name = azurerm_dns_zone.public_dns_zone[each.value.zone_key].resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.record

    content {
      priority = record.value.priority
      weight   = record.value.weight
      port     = record.value.port
      target   = record.value.target
    }
  }
  tags = each.value.tags
}