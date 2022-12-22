locals {
  empty_list   = []
  empty_map    = {}
  empty_string = ""
}

locals {
  root_id        = var.root_id
  root_name      = var.root_name
  root_parent_id = var.root_parent_id

  management_groups  = var.management_groups
  use_root_id_prefix = var.use_root_id_prefix

}



locals {
  root_management_group = {
    (local.root_id) = {
      id                         = "${local.root_id}"
      display_name               = local.root_name
      parent_management_group_id = local.root_parent_id
    }
  }

  child_management_groups_with_root_id_prefix = {
    for key, value in local.management_groups :
    "${local.root_id}-${key}" => {
      id                         = "${local.root_id}-${key}"
      display_name               = "${local.root_name}-${value.display_name}"
      parent_management_group_id = value.parent_management_group_id == "" ? "${local.root_id}" : "${local.root_id}-${value.parent_management_group_id}"
    }
  }

  child_management_groups_without_root_id_prefix = {
    for key, value in local.management_groups :
    "${key}" => {
      id                         = "${key}"
      display_name               = "${value.display_name}"
      parent_management_group_id = "${value.parent_management_group_id}"
    }
  }

  management_groups_merge = local.use_root_id_prefix ? merge(
    local.root_management_group,
    local.child_management_groups_with_root_id_prefix
  ) : merge(local.root_management_group, local.child_management_groups_without_root_id_prefix)

  management_groups_map = {
    for key, value in local.management_groups_merge :
    "${local.provider_path.management_groups}${key}" => {
      id                         = key
      display_name               = value.display_name
      parent_management_group_id = coalesce(value.parent_management_group_id, local.root_parent_id)
    }
  }

}

locals {
  azurerm_management_group_level_1 = {
    for key, value in local.management_groups_map :
    key => value
    if value.parent_management_group_id == local.root_parent_id
  }
  azurerm_management_group_level_2 = {
    for key, value in local.management_groups_map :
    key => value
    if contains(keys(azurerm_management_group.level_1), try(length(value.parent_management_group_id) > 0, false) ? "${local.provider_path.management_groups}${value.parent_management_group_id}" : local.empty_string)
  }
  azurerm_management_group_level_3 = {
    for key, value in local.management_groups_map :
    key => value
    if contains(keys(azurerm_management_group.level_2), try(length(value.parent_management_group_id) > 0, false) ? "${local.provider_path.management_groups}${value.parent_management_group_id}" : local.empty_string)
  }
  azurerm_management_group_level_4 = {
    for key, value in local.management_groups_map :
    key => value
    if contains(keys(azurerm_management_group.level_3), try(length(value.parent_management_group_id) > 0, false) ? "${local.provider_path.management_groups}${value.parent_management_group_id}" : local.empty_string)
  }
  azurerm_management_group_level_5 = {
    for key, value in local.management_groups_map :
    key => value
    if contains(keys(azurerm_management_group.level_4), try(length(value.parent_management_group_id) > 0, false) ? "${local.provider_path.management_groups}${value.parent_management_group_id}" : local.empty_string)
  }
  azurerm_management_group_level_6 = {
    for key, value in local.management_groups_map :
    key => value
    if contains(keys(azurerm_management_group.level_5), try(length(value.parent_management_group_id) > 0, false) ? "${local.provider_path.management_groups}${value.parent_management_group_id}" : local.empty_string)
  }
}

# The following local is used to merge the Management Group
# configuration from each level back into a single data
# object to return in the module outputs.
locals {
  module_output = merge(
    azurerm_management_group.level_1,
    azurerm_management_group.level_2,
    azurerm_management_group.level_3,
    azurerm_management_group.level_4,
    azurerm_management_group.level_5,
    azurerm_management_group.level_6,
  )
}

locals {
  provider_path = {
    management_groups = "/providers/Microsoft.Management/managementGroups/"
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