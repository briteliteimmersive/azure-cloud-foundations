## Inputs
variable "gh_token" {
  type      = string
  sensitive = true
  default   = null
}

variable "gh_org_name" {
  type    = string
  default = "briteliteimmersive"
}

variable "gh_base_url" {
  type    = string
  default = null
}

## Run-Time variables
locals {

  gh_environment_list = flatten([
    for spn_key, spn in local.sub_spns : [
      for gh_env in coalesce(spn.gh_environments, []) : {
        gh_env_key                = format("%s/%s", gh_env.name, spn_key)
        name                      = gh_env.name
        repo_full_name            = format("%s/%s", var.gh_org_name, gh_env.repo_name)
        spn_key                   = spn_key
        reviewers                 = gh_env.reviewers
        branch_protection_enabled = gh_env.branch_protection_enabled
      }
    ]
  ])

  gh_environments = {
    for gh_env in local.gh_environment_list : gh_env.gh_env_key => gh_env
  }

  gh_repos = toset([
    for gh_env in local.gh_environments : gh_env.repo_full_name
  ])

  gh_env_reviewer_users = toset(flatten([
    for gh_env_key, gh_env in local.gh_environments : [
      for user in gh_env.reviewers.usernames : user
    ]
  ]))

  gh_env_reviewer_teams = toset(flatten([
    for gh_env_key, gh_env in local.gh_environments : [
      for team in gh_env.reviewers.teams : team
    ]
  ]))

}

data "github_repository" "repo" {
  for_each  = local.gh_repos
  full_name = each.value
}

data "github_user" "user" {
  for_each = local.gh_env_reviewer_users
  username = each.value
}

data "github_team" "team" {
  for_each = local.gh_env_reviewer_teams
  slug     = each.value
}

resource "github_repository_environment" "repo_environment" {
  for_each    = local.gh_environments
  repository  = data.github_repository.repo[each.value.repo_full_name].name
  environment = each.value.name
  dynamic "reviewers" {
    for_each = [each.value.reviewers]

    content {
      users = [
        for username in reviewers.value.usernames : data.github_user.user[username].id
      ]

      teams = [
        for team in reviewers.value.teams : data.github_team.team[team].id
      ]
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = each.value.branch_protection_enabled ? [1] : []

    content {
      protected_branches     = true
      custom_branch_policies = false
    }
  }
}

resource "github_actions_environment_secret" "spn_client_id" {
  for_each        = local.gh_environments
  repository      = data.github_repository.repo[each.value.repo_full_name].name
  environment     = github_repository_environment.repo_environment[each.key].environment
  secret_name     = "ARM_CLIENT_ID"
  plaintext_value = azuread_service_principal.sub_app_spn[each.value.spn_key].application_id
}

resource "github_actions_environment_secret" "spn_client_secret" {
  for_each        = local.gh_environments
  repository      = data.github_repository.repo[each.value.repo_full_name].name
  environment     = github_repository_environment.repo_environment[each.key].environment
  secret_name     = "ARM_CLIENT_SECRET"
  plaintext_value = azuread_service_principal_password.sub_app_spn_credentials[each.value.spn_key].value
}

locals {

  static_secrets = {
    "ARM_SUBSCRIPTION_ID"                   = local.subscription_id
    "ARM_TENANT_ID"                         = local.client_tenant_id
    "TF_BACKEND_RESOURCE_GROUP_NAME"        = local.terraform_backend_storage_rgp
    "TF_BACKEND_STORAGE_ACC_CONTAINER_NAME" = local.terraform_backend_storage_container_name
    "TF_BACKEND_STORAGE_ACC_NAME"           = local.terraform_backend_storage_name
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
