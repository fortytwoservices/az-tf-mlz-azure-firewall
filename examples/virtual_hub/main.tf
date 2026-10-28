# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "virtual_hub" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-afwhub-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "virtual_wan" {
  type      = "Microsoft.Network/virtualWans@2024-05-01"
  name      = "vwan-mlz-afwhub-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = { type = "Standard" }
  }

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "virtual_hub" {
  type      = "Microsoft.Network/virtualHubs@2024-05-01"
  name      = "vhub-mlz-afwhub-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressPrefix = "10.100.0.0/23"
      sku           = "Standard"
      virtualWan    = { id = azapi_resource.virtual_wan.id }
    }
  }

  response_export_values = []
  tags                   = local.tags

  timeouts {
    create = "60m"
    delete = "60m"
  }
}

module "azure_firewall" {
  source = "../../"

  name      = "afw-mlz-afwhub-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  virtual_hub = {
    virtual_hub_id = azapi_resource.virtual_hub.id
    routing_intent = {}
  }
  firewall_policy = {
    name = "afwp-mlz-afwhub-${random_string.suffix.result}"
    dns  = { proxy_enabled = true }
  }
  rule_collection_groups = {
    platform = {
      priority = 200
      network_rule_collections = {
        spokes = {
          priority = 300
          action   = "Allow"
          rules = {
            dns = {
              description           = "DNS from the spokes to Azure DNS"
              protocols             = ["UDP", "TCP"]
              source_addresses      = ["10.0.0.0/8"]
              destination_addresses = ["168.63.129.16"]
              destination_ports     = ["53"]
            }
          }
        }
      }
    }
  }
  tags = local.tags
}
