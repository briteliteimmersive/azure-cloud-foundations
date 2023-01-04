locals {
  role_assignment_list = try(local.subscription_config["app_sub"].additional_settings.role_assignments, [])

  role_assignments = flatten([
    for role_assignment in local.role_assignment_list :
    [
      for object_id in role_assignment.object_ids :
      {
        role_assignment_key = "${role_assignment.role_definition_id}_${object_id}"
        role_definition_id  = format("/subscriptions/%s/providers/Microsoft.Authorization/roleDefinitions/%s", azurerm_subscription.application_sub["app_sub"].subscription_id, role_assignment.role_definition_id)
        object_id           = object_id
      }
  ]])

  role_assignments_to_deploy = {
    for role_assignment in local.role_assignments :
    role_assignment.role_assignment_key => role_assignment
  }
}

resource "azurerm_role_assignment" "application_sub_role_assignments" {
  for_each           = local.role_assignments_to_deploy
  scope              = format("/subscriptions/%s", azurerm_subscription.application_sub["app_sub"].subscription_id)
  role_definition_id = each.value.role_definition_id
  principal_id       = each.value.object_id
}