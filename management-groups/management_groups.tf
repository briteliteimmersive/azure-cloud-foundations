resource "azurerm_management_group" "level_1" {
  for_each = local.azurerm_management_group_level_1

  name                       = each.value.id
  display_name               = each.value.display_name
  parent_management_group_id = "${local.provider_path.management_groups}${each.value.parent_management_group_id}"


}

resource "azurerm_management_group" "level_2" {
  for_each = local.azurerm_management_group_level_2

  name                       = each.value.id
  display_name               = each.value.display_name
  parent_management_group_id = "${local.provider_path.management_groups}${each.value.parent_management_group_id}"


  depends_on = [azurerm_management_group.level_1]

}

resource "azurerm_management_group" "level_3" {
  for_each = local.azurerm_management_group_level_3

  name                       = each.value.id
  display_name               = each.value.display_name
  parent_management_group_id = "${local.provider_path.management_groups}${each.value.parent_management_group_id}"


  depends_on = [azurerm_management_group.level_2]

}

resource "azurerm_management_group" "level_4" {
  for_each = local.azurerm_management_group_level_4

  name                       = each.value.id
  display_name               = each.value.display_name
  parent_management_group_id = "${local.provider_path.management_groups}${each.value.parent_management_group_id}"


  depends_on = [azurerm_management_group.level_3]

}

resource "azurerm_management_group" "level_5" {
  for_each = local.azurerm_management_group_level_5

  name                       = each.value.id
  display_name               = each.value.display_name
  parent_management_group_id = "${local.provider_path.management_groups}${each.value.parent_management_group_id}"


  depends_on = [azurerm_management_group.level_4]

}

resource "azurerm_management_group" "level_6" {
  for_each = local.azurerm_management_group_level_6

  name                       = each.value.id
  display_name               = each.value.display_name
  parent_management_group_id = "${local.provider_path.management_groups}${each.value.parent_management_group_id}"


  depends_on = [azurerm_management_group.level_5]

}

resource "time_sleep" "after_azurerm_management_group" {
  depends_on = [
    azurerm_management_group.level_1,
    azurerm_management_group.level_2,
    azurerm_management_group.level_3,
    azurerm_management_group.level_4,
    azurerm_management_group.level_5,
    azurerm_management_group.level_6,
  ]

  triggers = {
    "azurerm_management_group_level_1" = jsonencode(keys(azurerm_management_group.level_1))
    "azurerm_management_group_level_2" = jsonencode(keys(azurerm_management_group.level_2))
    "azurerm_management_group_level_3" = jsonencode(keys(azurerm_management_group.level_3))
    "azurerm_management_group_level_4" = jsonencode(keys(azurerm_management_group.level_4))
    "azurerm_management_group_level_5" = jsonencode(keys(azurerm_management_group.level_5))
    "azurerm_management_group_level_6" = jsonencode(keys(azurerm_management_group.level_6))
  }

  create_duration  = local.create_duration_delay["after_azurerm_management_group"]
  destroy_duration = local.destroy_duration_delay["after_azurerm_management_group"]
}

