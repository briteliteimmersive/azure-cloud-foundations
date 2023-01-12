locals {
  subsciption_budget_list = try(local.subscription_config["app_sub"].additional_settings.budgets, [])

  subsciption_budgets = {
    for budget in local.subsciption_budget_list :
    "${local.subscription_config["app_sub"].subscription_name}-${budget.budget_name}" => budget
  }
}

## Create consumption budgets for new subscription
resource "azurerm_consumption_budget_subscription" "application_sub_budget" {
  for_each        = local.subsciption_budgets
  name            = each.value.budget_name
  subscription_id = azurerm_subscription.application_sub["app_sub"].id
  amount          = each.value.budget_amount
  time_grain      = try(each.value.time_grain, "Monthly")

  time_period {
    start_date = try(each.value.time_period.star_date, join("", [formatdate("YYYY-MM", timestamp()), "-01T00:00:00Z"]))
    end_date   = try(each.value.time_period.end_date, null)
  }

  dynamic "notification" {
    for_each = each.value.notifications
    content {
      enabled        = try(notification.value["enabled"], true)
      operator       = notification.value["operator"]
      threshold      = notification.value["threshold"]
      threshold_type = try(notification.value["threshold_type"], "Actual")
      contact_emails = try(notification.value["contact_emails"], null)
    }
  }

}