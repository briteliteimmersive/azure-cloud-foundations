variable "log_analytics_config" {
  type = object({
    name                = string
    resource_group_name = string
    sku                 = string
    automation_account = object(
      {
        name = string
        sku  = optional(string)
      }
    )
    settings = object({
      retention_in_days                           = number
      enable_monitoring_for_arc                   = bool
      enable_monitoring_for_vm                    = bool
      enable_monitoring_for_vmss                  = bool
      enable_solution_for_agent_health_assessment = bool
      enable_solution_for_anti_malware            = bool
      enable_solution_for_azure_activity          = bool
      enable_solution_for_change_tracking         = bool
      enable_solution_for_service_map             = bool
      enable_solution_for_sql_assessment          = bool
      enable_solution_for_updates                 = bool
      enable_solution_for_vm_insights             = bool
      enable_sentinel                             = bool
    })
    tags = optional(map(string))
  })
}

## Run-time variables
locals {
  log_analytics_config = var.log_analytics_config

  deploy_azure_monitor_solutions = {
    AgentHealthAssessment = local.log_analytics_config.settings.enable_solution_for_agent_health_assessment
    AntiMalware           = local.log_analytics_config.settings.enable_solution_for_anti_malware
    AzureActivity         = local.log_analytics_config.settings.enable_solution_for_azure_activity
    ChangeTracking        = local.log_analytics_config.settings.enable_solution_for_change_tracking
    Security              = local.log_analytics_config.settings.enable_sentinel
    SecurityInsights      = local.log_analytics_config.settings.enable_sentinel
    ServiceMap            = local.log_analytics_config.settings.enable_solution_for_service_map
    SQLAssessment         = local.log_analytics_config.settings.enable_solution_for_sql_assessment
    Updates               = local.log_analytics_config.settings.enable_solution_for_updates
    VMInsights            = local.log_analytics_config.settings.enable_solution_for_vm_insights
  }


  azurerm_log_analytics_workspace = {
    name                              = local.log_analytics_config.name
    location                          = local.location
    sku                               = try(local.log_analytics_config.sku, "PerGB2018") == null ? "PerGB2018" : local.log_analytics_config.sku
    retention_in_days                 = try(local.log_analytics_config.retention_in_days, local.log_analytics_config.settings.retention_in_days)
    daily_quota_gb                    = try(local.log_analytics_config.daily_quota_gb, null)
    internet_ingestion_enabled        = try(local.log_analytics_config.internet_ingestion_enabled, true)
    internet_query_enabled            = try(local.log_analytics_config.internet_query_enabled, true)
    reservation_capcity_in_gb_per_day = try(local.log_analytics_config.reservation_capcity_in_gb_per_day, null) # Requires version = "~> 2.48.0"
    tags                              = merge(local.log_analytics_config.tags, local.common_resource_tags)
    resource_group_name               = local.log_analytics_config.resource_group_name
  }

  azurerm_automation_account = {
    name                = local.log_analytics_config.automation_account.name
    location            = local.location
    resource_group_name = local.log_analytics_config.resource_group_name
    sku                 = try(local.log_analytics_config.automation_account.sku, "Basic") == null ? "Basic" : local.log_analytics_config.automation_account.sku
    tags                = merge(local.log_analytics_config.tags, local.common_resource_tags)

  }

  azurerm_log_analytics_solution = [
    for solution_name, solution_enabled in local.deploy_azure_monitor_solutions :
    {
      solution_name = solution_name
      location      = local.location
      tags          = merge(local.log_analytics_config.tags, local.common_resource_tags)
      plan = {
        publisher = "Microsoft"
        product   = "OMSGallery/${solution_name}"
      }
      resource_group_name = local.log_analytics_config.resource_group_name
    }
    if solution_enabled
  ]

  azurerm_log_analytics_solution_management = {
    for resource in local.azurerm_log_analytics_solution :
    resource.solution_name => resource
  }
}

resource "azurerm_resource_group" "management" {
  # Mandatory resource attributes
  name     = local.log_analytics_config.resource_group_name
  location = local.location
  tags     = local.common_resource_tags
}

resource "azurerm_log_analytics_workspace" "management" {
  # Mandatory resource attributes
  name                = local.azurerm_log_analytics_workspace.name
  location            = local.azurerm_log_analytics_workspace.location
  resource_group_name = local.azurerm_log_analytics_workspace.resource_group_name

  # Optional resource attributes
  sku                        = local.azurerm_log_analytics_workspace.sku
  retention_in_days          = local.azurerm_log_analytics_workspace.retention_in_days
  daily_quota_gb             = local.azurerm_log_analytics_workspace.daily_quota_gb
  internet_ingestion_enabled = local.azurerm_log_analytics_workspace.internet_ingestion_enabled
  internet_query_enabled     = local.azurerm_log_analytics_workspace.internet_query_enabled
  tags                       = local.azurerm_log_analytics_workspace.tags

  # Set explicit dependency on Resource Group deployment
  depends_on = [
    azurerm_resource_group.management,
  ]

}

resource "azurerm_automation_account" "management" {
  # Mandatory resource attributes
  name                = local.azurerm_automation_account.name
  location            = local.azurerm_automation_account.location
  resource_group_name = local.azurerm_automation_account.resource_group_name

  # Optional resource attributes
  sku_name = local.azurerm_automation_account.sku
  tags     = local.azurerm_automation_account.tags
  # Set explicit dependency on Resource Group deployment
  depends_on = [
    azurerm_resource_group.management,
  ]

}

resource "azurerm_log_analytics_linked_service" "management" {

  # Mandatory resource attributes
  resource_group_name = local.azurerm_automation_account.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.management.id

  # Optional resource attributes
  read_access_id = azurerm_automation_account.management.id

  # Set explicit dependency on Resource Group, Log Analytics workspace and Automation Account deployments
  depends_on = [
    azurerm_resource_group.management,
    azurerm_log_analytics_workspace.management,
    azurerm_automation_account.management,
  ]

}

resource "azurerm_log_analytics_solution" "management" {
  for_each = local.azurerm_log_analytics_solution_management
  # Mandatory resource attributes
  solution_name         = each.value.solution_name
  location              = each.value.location
  resource_group_name   = each.value.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.management.id
  workspace_name        = azurerm_log_analytics_workspace.management.name

  plan {
    publisher = each.value.plan.publisher
    product   = each.value.plan.product
  }

  # Optional resource attributes
  tags = each.value.tags

  # Set explicit dependency on Resource Group, Log Analytics
  # workspace and Automation Account
  depends_on = [
    azurerm_resource_group.management,
    azurerm_log_analytics_workspace.management,
    azurerm_automation_account.management,
    azurerm_log_analytics_linked_service.management,
  ]

}