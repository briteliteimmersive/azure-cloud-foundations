locals {
  subscription_config = var.subscription_config != null ? { "app_sub" : var.subscription_config } : {}

  sub_billing_info = try(length(local.subscription_config.app_sub.additional_settings.billng_info), 0) > 0 ? {
    "app_sub" = {
      billing_account_id = local.subscription_config.app_sub.additional_settings.billng_info.billing_account_id
      billing_profile_id = local.subscription_config.app_sub.additional_settings.billng_info.billing_profile_id
      invoice_section_id = local.subscription_config.app_sub.additional_settings.billng_info.invoice_section_id
    }
  } : {}
}


## Pull billing account info if subscription_config is not empty.
data "azurerm_billing_mca_account_scope" "billing_account_scope" {
  for_each             = local.sub_billing_info
  billing_account_name = each.value.billing_account_id
  billing_profile_name = each.value.billing_profile_id
  invoice_section_name = each.value.invoice_section_id
}

## Create a new susbcription if subscription_config is not empty.
resource "azurerm_subscription" "application_sub" {
  for_each          = local.subscription_config
  subscription_name = lower(each.value.subscription_name)
  billing_scope_id  = try(data.azurerm_billing_mca_account_scope.billing_account_scope[each.key].id, null)
  subscription_id   = try(each.value.additional_settings.subscription_id, null)
  workload          = "Production"
  tags = merge(each.value.tags, {
    "deployed-by" = var.deployment_info
  })
}

## Pull management group info if subscription_config is not empty.
data "azurerm_management_group" "mgmt_grp" {
  for_each = local.subscription_config
  name     = each.value.management_group_id
}

## Associate the new subscription to a management group if subscription_config is not empty.
resource "azurerm_management_group_subscription_association" "app_sub_mgmt_grp_association" {
  for_each            = local.subscription_config
  management_group_id = data.azurerm_management_group.mgmt_grp[each.key].id
  subscription_id     = format("/subscriptions/%s", azurerm_subscription.application_sub[each.key].subscription_id)
}