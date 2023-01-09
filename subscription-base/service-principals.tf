## Input variables
variable "subscription_spns" {
  type = list(object(
    {
      name               = string
      role_definition_id = optional(string)
      gh_environment = optional(object(
        {
          name           = string
          repo_full_name = string
        }
      ))
      tags = optional(list(string), [])
    }
  ))

  default = []
}

## Run-time variables
locals {

  sub_spns = {
    for spn in var.subscription_spns : lower(format("%s/%s", local.client_object_id, spn.name)) => {
      spn_key      = lower(format("%s/%s", local.client_object_id, spn.name))
      keyvault_key = lower(format("%s/%s", local.resource_groups.admin_rg.name, local.admin_keyvault.name))
      name         = spn.name,
      scope        = format("/subscriptions/%s", local.subscription_id)
      role_definition_id = spn.role_definition_id != null ? format(
        "/subscriptions/%s/providers/Microsoft.Authorization/roleDefinitions/%s",
        local.subscription_id,
        spn.role_definition_id
      ) : null
      tags           = concat(["created-by-terraform"], spn.tags)
      gh_environment = spn.gh_environment
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

resource "azuread_service_principal_password" "sub_app_spn_credentials" {
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

resource "azurerm_key_vault_secret" "spn_client_ids" {
  for_each     = local.sub_spns
  name         = upper(replace(format("%s-client-id", each.value.name), "_", "-"))
  value        = azuread_service_principal.sub_app_spn[each.key].application_id
  key_vault_id = azurerm_key_vault.admin_keyvault[each.value.keyvault_key].id
  depends_on = [
    azurerm_role_assignment.sub_spn_assignment
  ]
}

resource "azurerm_key_vault_secret" "spn_client_secrets" {
  for_each     = local.sub_spns
  name         = upper(replace(format("%s-client-secret", each.value.name), "_", "-"))
  value        = azuread_service_principal_password.sub_app_spn_credentials[each.key].value
  key_vault_id = azurerm_key_vault.admin_keyvault[each.value.keyvault_key].id
  depends_on = [
    azurerm_role_assignment.sub_spn_assignment
  ]
}

data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  application_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing   = true
}

resource "azuread_app_role_assignment" "app_azuread_role_assignment" {
  provider            = azuread.azuread_spn
  for_each            = local.sub_spns
  app_role_id         = azuread_service_principal.msgraph.app_role_ids["Application.Read.All"]
  principal_object_id = azuread_service_principal.sub_app_spn[each.key].object_id
  resource_object_id  = azuread_service_principal.msgraph.object_id
}