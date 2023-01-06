## Input variables
variable "subscription_spns" {
  type = list(object(
    {
      serial_no          = number
      name               = optional(string)
      role_definition_id = optional(string)
      tags               = optional(list(string), [])
    }
  ))

  default = []
}

## Run-time data inputs
data "azurerm_role_definition" "role" {
  for_each           = local.spn_roles
  role_definition_id = each.value
}

## Run-time variables
locals {

  spn_roles = toset([
    for spn in var.subscription_spns : spn.role_definition_id if spn.role_definition_id != null
  ])

  role_codes = {
    for role in data.azurerm_role_definition.role : basename(role.id) => lookup(local.builtin_role_code_map, role.name, local.custom_role_code)
  }

  ## Example - "SPN-AZTS-C-P001"
  spn_naming_format = "spn-%s-%s-%s%03d"

  sub_spns = {
    for spn in var.subscription_spns : lower(format("%s-spn-%s%d", local.subscription_name, local.infra_env_code, spn.serial_no)) => {
      resource_key = lower(format("%s-spn-%s%d", local.subscription_name, local.infra_env_code, spn.serial_no))
      name = lower(
        coalesce(
          spn.name,
          format(
            local.spn_naming_format,
            local.app_unique_code,
            try(lookup(local.role_codes, spn.role_definition_id), local.custom_role_code),
            local.infra_env_code,
            spn.serial_no
          )
        )
      )
      scope = format("/subscriptions/%s", local.subscription_id)
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
  owners       = [data.azuread_client_config.current_tenant.object_id]
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