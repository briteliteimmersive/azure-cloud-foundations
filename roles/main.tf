resource "azurerm_role_definition" "enterprise_scale" {
  for_each = local.archetype_role_definitions_map

  # Special handling of OPTIONAL role_definition_id to ensure consistent and
  # correct mapping of Terraform state ADDR value to Azure Resource ID value.
  role_definition_id = basename(each.key)

  # Mandatory resource attributes
  name  = "[${basename(upper(local.scope_id))}] ${each.value.roleName}"
  scope = local.scope_id

  permissions {
    actions          = try(each.value.permissions[0].actions, local.empty_list)
    not_actions      = try(each.value.permissions[0].notActions, local.empty_list)
    data_actions     = try(each.value.permissions[0].dataActions, local.empty_list)
    not_data_actions = try(each.value.permissions[0].notDataActions, local.empty_list)
  }

  # Optional resource attributes
  description       = try(each.value.description, "${each.value.roleName} Role Definition at scope ${local.scope_id}")
  assignable_scopes = try(length(each.value.assignableScopes) > 0, false) ? each.value.assignableScopes : [local.scope_id, ]

  # Set explicit dependency on Management Group deployments
  depends_on = [
    #time_sleep.after_azurerm_management_group,
  ]

}

resource "time_sleep" "after_azurerm_role_definition" {
  depends_on = [
    # time_sleep.after_azurerm_management_group,
    # azurerm_role_definition.enterprise_scale,
  ]

  triggers = {
    "azurerm_role_definition_enterprise_scale" = jsonencode(keys(azurerm_role_definition.enterprise_scale))
  }

  create_duration  = local.create_duration_delay["after_azurerm_role_definition"]
  destroy_duration = local.destroy_duration_delay["after_azurerm_role_definition"]
}