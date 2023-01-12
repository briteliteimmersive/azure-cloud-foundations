## Inputs
variable "gh_token" {
  type      = string
  sensitive = true
  default   = null
}

variable "gh_org_name" {
  type    = string
  default = null
}

variable "gh_base_url" {
  type    = string
  default = null
}

## Run-Time variables
locals {

  gh_environments = {
    for spn_key, spn in local.sub_spns : spn_key => merge(spn, {
      repo_full_name = format("%s/%s", var.gh_org_name, spn.gh_environment.repo_name)
    }) if spn.gh_environment != null
  }

  gh_repos = toset([
    for spn in local.gh_environments : format("%s/%s", var.gh_org_name, spn.gh_environment.repo_name)
  ])

}

data "github_repository" "repo" {
  for_each  = local.gh_repos
  full_name = each.value
}

resource "github_repository_environment" "repo_environment" {
  for_each    = local.gh_environments
  repository  = data.github_repository.repo[each.value.repo_full_name].name
  environment = each.value.gh_environment.name
}

resource "github_actions_environment_secret" "spn_client_id" {
  for_each        = local.gh_environments
  repository      = data.github_repository.repo[each.value.repo_full_name].name
  environment     = github_repository_environment.repo_environment[each.key].environment
  secret_name     = "ARM_CLIENT_ID"
  plaintext_value = azuread_service_principal.sub_app_spn[each.key].application_id
}

resource "github_actions_environment_secret" "spn_client_secret" {
  for_each        = local.gh_environments
  repository      = data.github_repository.repo[each.value.repo_full_name].name
  environment     = github_repository_environment.repo_environment[each.key].environment
  secret_name     = "ARM_CLIENT_SECRET"
  plaintext_value = azuread_service_principal_password.sub_app_spn_credentials[each.key].value
}

locals {

  static_secrets = {
    "ARM_SUBSCRIPTION_ID"                   = local.subscription_id
    "ARM_TENANT_ID"                         = local.client_tenant_id
    "TF_BACKEND_RESOURCE_GROUP_NAME"        = local.terraform_backend_storage_rgp
    "TF_BACKEND_STORAGE_ACC_CONTAINER_NAME" = local.terraform_backend_storage_container_name
    "TF_BACKEND_STORAGE_ACC_NAME"           = local.terraform_backend_storage_container_name
    "TF_BACKEND_SUBSCRIPTION_ID"            = local.subscription_id
  }

  gh_environment_static_secret_list = flatten([
    for env_key, env in local.gh_environments : [
      for secret_key, secret_value in local.static_secrets : {
        env_key        = env_key
        secret_name    = secret_key
        secret_value   = secret_value
        repo_full_name = env.repo_full_name
        env_secret_key = format("%s/%s", env_key, secret_key)
      }
    ]
  ])

  gh_environment_static_secrets = {
    for secret in local.gh_environment_static_secret_list : secret.env_secret_key => secret
  }

}

resource "github_actions_environment_secret" "static_secret" {
  for_each        = local.gh_environment_static_secrets
  repository      = data.github_repository.repo[each.value.repo_full_name].name
  environment     = github_repository_environment.repo_environment[each.value.env_key].environment
  secret_name     = each.value.secret_name
  plaintext_value = each.value.secret_value
}