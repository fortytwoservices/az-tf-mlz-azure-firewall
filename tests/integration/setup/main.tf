# A resource group, a hub virtual network with the firewall subnets, and a Log Analytics workspace for one
# integration test run.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-it-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = "norwayeast"
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-mlz-it-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.0.0.0/24"] }
    }
  }
}

resource "azapi_resource" "firewall_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "AzureFirewallSubnet"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = { addressPrefixes = ["10.0.0.0/26"] }
  }
  locks = [azapi_resource.virtual_network.id]
}

resource "azapi_resource" "management_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "AzureFirewallManagementSubnet"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = { addressPrefixes = ["10.0.0.64/26"] }
  }
  locks = [azapi_resource.virtual_network.id]
}

resource "azapi_resource" "workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = "log-mlz-it-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }
}

output "firewall_subnet_id" {
  value = azapi_resource.firewall_subnet.id
}

output "management_subnet_id" {
  value = azapi_resource.management_subnet.id
}

output "workspace_id" {
  value = azapi_resource.workspace.id
}

output "location" {
  value = azapi_resource.resource_group.location
}

output "object_id" {
  value = data.azapi_client_config.current.object_id
}

output "resource_group_id" {
  value = azapi_resource.resource_group.id
}

output "suffix" {
  value = random_string.suffix.result
}
