data "azurerm_management_group" "mg_grp" {
  name = var.management_group_id
}
locals {
  empty_list   = []
  empty_map    = {}
  empty_string = ""
}

locals {
  root_id                           = var.management_group_id  
  scope_id                          =  data.azurerm_management_group.mg_grp.id
  template_file_variables           = var.template_file_variables 

}

locals {
  builtin_library_path = "${path.module}/lib"
}






locals {
  base_module_tags = {
    deployedBy = "terraform/landingzones/policy"
  }

}
#Manipulate the exclusion files
locals{
 
   exclude_builtin_policy_definitions_from_json_path = [for filepath in var.policy_definition_exclusions : "policy_definitions/${filepath}.json"]
   exclude_builtin_policy_sets_from_json_path = [for filepath in var.policy_set_exclusions : "policy_set_definitions/${filepath}.json"]
   
}
locals {
  core_template_file_variables = {
    root_scope_id             = basename(local.root_id)
    root_scope_resource_id    = local.scope_id #local.root_id
    current_scope_id          = basename(local.scope_id)
    current_scope_resource_id = local.scope_id
    builtin                   = local.builtin_library_path
    builtin_library_path      = local.builtin_library_path
  }
  template_file_vars = merge(
    local.template_file_variables,
    local.core_template_file_variables,
  )
}

locals {
  module_output = {
    
  }
}

locals {
  # scope_is_management_group = length(regexall("^/providers/Microsoft.Management/managementGroups/.*", local.scope_id)) > 0
  # scope_is_subscription     = length(regexall("^/subscriptions/.*", local.scope_id)) > 0
  resource_types = {
    policy_assignment     = "Microsoft.Authorization/policyAssignments"
    policy_definition     = "Microsoft.Authorization/policyDefinitions"
    policy_set_definition = "Microsoft.Authorization/policySetDefinitions"
    role_assignment       = "Microsoft.Authorization/roleAssignments"
    role_definition       = "Microsoft.Authorization/roleDefinitions"
  }
  provider_path = {
    /*policy_assignment     = "${local.scope_id}/providers/Microsoft.Authorization/policyAssignments/"
    policy_definition     = "${local.scope_id}/providers/Microsoft.Authorization/policyDefinitions/"
    policy_set_definition = "${local.scope_id}/providers/Microsoft.Authorization/policySetDefinitions/"
    role_assignment       = "${local.scope_id}/providers/Microsoft.Authorization/roleAssignments/"
    role_definition       = "/providers/Microsoft.Authorization/roleDefinitions/"*/
    policy_assignment     = "${local.scope_id}/Microsoft.Authorization/policyAssignments/"
    policy_definition     = "${local.scope_id}/Microsoft.Authorization/policyDefinitions/"
    policy_set_definition = "${local.scope_id}/Microsoft.Authorization/policySetDefinitions/"
    role_assignment       = "${local.scope_id}/Microsoft.Authorization/roleAssignments/"
    role_definition       = "/Microsoft.Authorization/roleDefinitions/"
  }
}

# The following locals are used to control time_sleep
# delays between resources to reduce transient errors
# relating to replication delays in Azure
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