
data "azurerm_subscription" "primary" {
}
data "azurerm_client_config" "current" {
}
data "azurerm_management_group" "mg_grp" {
  name = var.root_id
}
locals {
  empty_list   = []
  empty_map    = {}
  empty_string = ""
}

locals {
  root_id                 = var.root_id
  default_tags            = var.default_tags
  template_file_variables = var.template_file_variables
  role_definitions_path   = "${path.module}/definitions"
  #scope_id                          = "${local.provider_path.management_groups}${local.root_id}"  
  #scope_id                          = data.azurerm_subscription.primary.id
  scope_id = data.azurerm_management_group.mg_grp.id
}

# The following locals are used in template functions to provide values
locals {
  core_template_file_variables = {
    root_scope_id             = basename(local.root_id)
    root_scope_resource_id    = local.root_id
    current_scope_id          = basename(local.root_id)
    current_scope_resource_id = local.scope_id
    builtin                   = local.role_definitions_path
    builtin_library_path      = local.role_definitions_path
    custom                    = local.role_definitions_path #Probably can delete
    custom_library_path       = local.role_definitions_path #Probably can delete
  }
  template_file_vars = merge(
    local.template_file_variables,
    local.core_template_file_variables,
  )
}
locals {

  exclude_builtin_role_definitions_from_json_path = [for filepath in var.exclude_builtin_role_definitions_from_json : "${filepath}.json"]

}
locals {
  role_definitions_from_json = tolist(fileset(local.role_definitions_path, "**"))
  role_definitions_from_yaml = tolist(fileset(local.role_definitions_path, "**/rd_*.{yml,yml.tftpl,yaml,yaml.tftpl}"))
  # exclude_builtin_roles_definitions_from_json = 
  builtin_role_definitions_from_json_inclusion = setsubtract(local.role_definitions_from_json, local.exclude_builtin_role_definitions_from_json_path)

  role_definitions_dataset_from_json = try(length(local.builtin_role_definitions_from_json_inclusion) > 0, false) ? {
    for filepath in local.builtin_role_definitions_from_json_inclusion :
    filepath => jsondecode(templatefile("${local.role_definitions_path}/${filepath}", local.template_file_vars))
  } : null
  role_definitions_dataset_from_yaml = try(length(local.role_definitions_from_yaml) > 0, false) ? {
    for filepath in local.role_definitions_from_yaml :
    filepath => yamldecode(templatefile("${local.role_definitions_path}/${filepath}", local.template_file_vars))
  } : null
}


# If Role Definition datasets exist, convert to map
locals {
  role_definitions_map_from_json = try(length(local.role_definitions_dataset_from_json) > 0, false) ? {
    for key, value in local.role_definitions_dataset_from_json :
    uuidv5(value.name, local.scope_id) => value
    if value.type == local.resource_types.role_definition
  } : null
  role_definitions_map_from_yaml = try(length(local.role_definitions_dataset_from_yaml) > 0, false) ? {
    for key, value in local.role_definitions_dataset_from_yaml :
    uuidv5(value.name, local.scope_id) => value
    if value.type == local.resource_types.role_definition
  } : null
}

# Merge the Role Definition maps into a single map.
# If duplicates exist due to a custom Role Definition being
# defined to override a built-in definition, this is handled by
# merging the custom policies after the built-in policies.
locals {
  archetype_role_definitions_map = merge(
    local.role_definitions_map_from_json,
    local.role_definitions_map_from_yaml
  )
}

# The following local is used to merge the Management Group
# configuration from each level back into a single data
# object to return in the module outputs.
locals {
  module_output = {
    # role_definitions_path = local.role_definitions_path
    # core_template_file_variables = local.core_template_file_variables
    # template_file_vars = local.template_file_vars
    # role_definitions_from_json = local.role_definitions_from_json
    # role_definitions_from_json = local.role_definitions_from_json
    # builtin_role_definitions_from_json_inclusion = local.builtin_role_definitions_from_json_inclusion
    # role_definitions_dataset_from_json = local.role_definitions_dataset_from_json
    # role_definitions_map_from_json = local.role_definitions_map_from_json
    # rolemap = local.archetype_role_definitions_map
    scope_id = local.scope_id

  }
}

locals {
  provider_path = {
    management_groups = "/providers/Microsoft.Management/managementGroups/"
    role_definition   = "/providers/Microsoft.Authorization/roleDefinitions/"
  }

  resource_types = {
    policy_assignment     = "Microsoft.Authorization/policyAssignments"
    policy_definition     = "Microsoft.Authorization/policyDefinitions"
    policy_set_definition = "Microsoft.Authorization/policySetDefinitions"
    role_assignment       = "Microsoft.Authorization/roleAssignments"
    role_definition       = "Microsoft.Authorization/roleDefinitions"
  }
}

locals {
  default_create_duration_delay  = "30s"
  default_destroy_duration_delay = "0s"
  create_duration_delay = {
    after_azurerm_management_group      = lookup(var.create_duration_delay, "azurerm_management_group", local.default_create_duration_delay)
    after_azurerm_policy_assignment     = lookup(var.create_duration_delay, "azurerm_policy_assignment", local.default_create_duration_delay)
    after_azurerm_policy_definition     = lookup(var.create_duration_delay, "azurerm_policy_definition", local.default_create_duration_delay)
    after_azurerm_policy_set_definition = lookup(var.create_duration_delay, "azurerm_policy_set_definition", local.default_create_duration_delay)
    after_azurerm_role_assignment       = lookup(var.create_duration_delay, "azurerm_role_assignment", local.default_create_duration_delay)
    after_azurerm_role_definition       = lookup(var.create_duration_delay, "azurerm_role_definition", local.default_create_duration_delay)
  }
  destroy_duration_delay = {
    after_azurerm_management_group      = lookup(var.destroy_duration_delay, "azurerm_management_group", local.default_destroy_duration_delay)
    after_azurerm_policy_assignment     = lookup(var.destroy_duration_delay, "azurerm_policy_assignment", local.default_destroy_duration_delay)
    after_azurerm_policy_definition     = lookup(var.destroy_duration_delay, "azurerm_policy_definition", local.default_destroy_duration_delay)
    after_azurerm_policy_set_definition = lookup(var.destroy_duration_delay, "azurerm_policy_set_definition", local.default_destroy_duration_delay)
    after_azurerm_role_assignment       = lookup(var.destroy_duration_delay, "azurerm_role_assignment", local.default_destroy_duration_delay)
    after_azurerm_role_definition       = lookup(var.destroy_duration_delay, "azurerm_role_definition", local.default_destroy_duration_delay)
  }
}