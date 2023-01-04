locals {
  security_center_contact = try(local.subscription_config["app_sub"].additional_settings.security_center_contact.email, null) != null ? {
    "${local.subscription_config.app_sub.additional_settings.security_center_contact.email}" = local.subscription_config["app_sub"].additional_settings.security_center_contact
  } : {}
}

# Optional: Create security center contact for new subscription
resource "azurerm_security_center_contact" "app_sub_security_contact" {
  for_each            = local.security_center_contact
  email               = each.value.email
  alert_notifications = each.value.alert_notifications
  alerts_to_admins    = each.value.alerts_to_admins
  phone               = try(each.value.phone, null)
  name                = try(each.value.name, null)
}