output "configuration" {
  value       = local.module_output
  description = "Returns the configuration data for all Management Groups created by this module."
}
output "FINAL_ROLE_JSON_INCLUDED_FOR_MANIPULATION" {
  value       = local.builtin_role_definitions_from_json_inclusion
  description = "FINAL  ROLE JSON INCLUDED FOR MANIPULATION"

}


