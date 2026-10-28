# A resource group, a Virtual WAN and a virtual hub for one integration test run (swedencentral: a Standard
# firewall failed twice in norwayeast on 2026-10-28). Creating the hub takes 20 to 30 minutes.
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
  location  = "swedencentral"
}

resource "azapi_resource" "virtual_wan" {
  type      = "Microsoft.Network/virtualWans@2024-05-01"
  name      = "vwan-mlz-it-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  body = {
    properties = { type = "Standard" }
  }
}

resource "azapi_resource" "virtual_hub" {
  type      = "Microsoft.Network/virtualHubs@2024-05-01"
  name      = "vhub-mlz-it-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  body = {
    properties = {
      addressPrefix = "10.100.0.0/23"
      sku           = "Standard"
      virtualWan    = { id = azapi_resource.virtual_wan.id }
    }
  }
  timeouts {
    create = "60m"
    delete = "60m"
  }
}

output "location" {
  value = azapi_resource.resource_group.location
}

output "resource_group_id" {
  value = azapi_resource.resource_group.id
}

output "suffix" {
  value = random_string.suffix.result
}

output "virtual_hub_id" {
  value = azapi_resource.virtual_hub.id
}
