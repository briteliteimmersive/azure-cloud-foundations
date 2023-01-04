variable "subscription_config" {
  type = object({
    subscription_name    = string
    management_group_id  = string
    tags                 = map(string)
    additional_settings   = any
  })

  default = null
}

variable "deployment_info" {
  type    = string
  default = "{“version”: “”, “commit-id”: “”, “pipeline-name”:””, “github-repo”: “”}"
}