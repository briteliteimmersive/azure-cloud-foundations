locals {
  ## Default
  az_location_code_map = {
    "westus" = "u7"
  }

  env_code_map = {
    "sandbox"          = "x"
    "dev"              = "d"
    "qa"               = "q"
    "stage"            = "s"
    "uat"              = "u"
    "non-prod"         = "n"
    "prod"             = "p"
    "transit-services" = "p"
    "global-shared"    = "p"
    "shared-services"  = "p"
  }

  builtin_role_code_map = {
    "Owner"       = "o"
    "Contributor" = "c"
    "Reader"      = "r"
  }

  custom_role_code = "z"

}

locals {
  ## Derived

  subscription_derivatives         = split("-", local.subscription_name)
  subscription_naming_prefix       = local.subscription_derivatives[0]
  subscription_ownership_territory = local.subscription_derivatives[1]
  subsription_env_code             = local.subscription_derivatives[2]
  infra_env_code                   = lookup(local.env_code_map, local.environment)
  az_location_code                 = lookup(local.az_location_code_map, local.location)
}