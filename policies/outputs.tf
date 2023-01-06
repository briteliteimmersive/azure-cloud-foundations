output "configuration" {
  value = local.module_output
  description = "Returns the configuration data for all Management Groups created by this module."
}



output "FINAL_POLICY_JSON_INCLUDED_FOR_MANIPULATION" {
  value= local.builtin_policy_definitions_from_json_inclusion
  description = "FINAL  POLICY JSON INCLUDED FOR MANIPULATION"
  
}

output "builtin-policy-set-definitions-from-json" {
  value= local.builtin_policy_set_definitions_from_json
  description = "builtin-policy-set-definitions-from-json"
  
}