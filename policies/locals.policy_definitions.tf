locals {
  builtin_policy_definitions_from_json = tolist(fileset(local.builtin_library_path, "**/policy_definitions/*.{json,json.tftpl}"))
  builtin_policy_definitions_from_yaml = tolist(fileset(local.builtin_library_path, "**/policy_definitions/*.{yml,yml.tftpl,yaml,yaml.tftpl}"))
}
locals {
  # exclude_builtin_policy_definitions_from_json = 
   builtin_policy_definitions_from_json_inclusion = setsubtract(local.builtin_policy_definitions_from_json, local.exclude_builtin_policy_definitions_from_json_path)
  
  
}
# If Policy Definition files exist, load content into dataset
locals {
  builtin_policy_definitions_dataset_from_json = try(length(local.builtin_policy_definitions_from_json_inclusion) > 0, false) ? {
    for filepath in local.builtin_policy_definitions_from_json_inclusion :
    filepath => jsondecode(templatefile("${local.builtin_library_path}/${filepath}", local.template_file_vars))
  } : null
  builtin_policy_definitions_dataset_from_yaml = try(length(local.builtin_policy_definitions_from_yaml) > 0, false) ? {
    for filepath in local.builtin_policy_definitions_from_yaml :
    filepath => yamldecode(templatefile("${local.builtin_library_path}/${filepath}", local.template_file_vars))
  } : null
  
}

# If Policy Definition datasets exist, convert to map
locals {
  builtin_policy_definitions_map_from_json = try(length(local.builtin_policy_definitions_dataset_from_json) > 0, false) ? {
    for key, value in local.builtin_policy_definitions_dataset_from_json :
    value.name => value
    if value.type == local.resource_types.policy_definition
  } : null
  builtin_policy_definitions_map_from_yaml = try(length(local.builtin_policy_definitions_dataset_from_yaml) > 0, false) ? {
    for key, value in local.builtin_policy_definitions_dataset_from_yaml :
    value.name => value
    if value.type == local.resource_types.policy_definition
  } : null
  
}

# Merge the Policy Definition maps into a single map.
# If duplicates exist due to a custom Policy Definition being
# defined to override a built-in definition, this is handled by
# merging the custom policies after the built-in policies.
locals {
  archetype_policy_definitions_map = merge(
    local.builtin_policy_definitions_map_from_json,
    local.builtin_policy_definitions_map_from_yaml,    
  )
}

# Extract the desired Policy Definitions from archetype_policy_definitions_map.
locals {
  archetype_policy_definitions = {
    for policy, template in local.archetype_policy_definitions_map :
    "${local.provider_path.policy_definition}${policy}" => {
      resource_id = "${local.provider_path.policy_definition}${policy}"
      scope_id    = local.scope_id
      template    = try(local.archetype_policy_definitions_map[policy], null)
    }
  }
}