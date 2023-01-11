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

resource "github_actions_environment_secret" "spn_subscription_id_secret" {
  for_each        = local.gh_environments
  repository      = data.github_repository.repo[each.value.repo_full_name].name
  environment     = github_repository_environment.repo_environment[each.key].environment
  secret_name     = "ARM_SUBSCRIPTION_ID"
  plaintext_value = local.subscription_id
}

resource "github_actions_environment_secret" "spn_tenant_id_secret" {
  for_each        = local.gh_environments
  repository      = data.github_repository.repo[each.value.repo_full_name].name
  environment     = github_repository_environment.repo_environment[each.key].environment
  secret_name     = "ARM_TENANT_ID"
  plaintext_value = local.client_tenant_id
}