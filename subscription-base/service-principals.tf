## Input variables
variable "subscription_spns" {
  type = list(object(
    {
      name               = string
      role_definition_id = optional(string)
      tags               = optional(list(string), [])
    }
  ))

  default = []
}

## Run-time variables
locals {

  sub_spns = {
    for spn in var.subscription_spns : lower(format("%s/%s", local.client_object_id, spn.name)) => {
      spn_key = lower(format("%s/%s", local.client_object_id, spn.name))
      name    = spn.name,
      scope   = format("/subscriptions/%s", local.subscription_id)
      role_definition_id = spn.role_definition_id != null ? format(
        "/subscriptions/%s/providers/Microsoft.Authorization/roleDefinitions/%s",
        local.subscription_id,
        spn.role_definition_id
      ) : null
      tags = concat(["created-by-terraform"], spn.tags)
    }
  }

  sub_spn_role_assignments = {
    for spn_key, spn in local.sub_spns : spn_key => spn if spn.role_definition_id != null
  }
}

resource "azuread_application" "sub_app" {
  for_each     = local.sub_spns
  display_name = each.value.name
  owners       = [local.client_object_id]
  tags         = each.value.tags
  provider     = azuread.azuread_spn
}

resource "azuread_service_principal" "sub_app_spn" {
  for_each       = local.sub_spns
  application_id = azuread_application.sub_app[each.key].application_id
  tags           = each.value.tags
  provider       = azuread.azuread_spn
}

resource "azuread_service_principal_password" "app_spn_credentials" {
  for_each             = local.sub_spns
  service_principal_id = azuread_service_principal.sub_app_spn[each.key].id
  provider             = azuread.azuread_spn
}

resource "azurerm_role_assignment" "sub_spn_assignment" {
  for_each           = local.sub_spn_role_assignments
  scope              = each.value.scope
  role_definition_id = each.value.role_definition_id
  principal_id       = azuread_service_principal.sub_app_spn[each.key].object_id
}