# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  # A Standard firewall failed twice in norwayeast on 2026-10-28 (terminal state Failed,
  # InternalServerError, after 18 minutes) while the same example succeeded here.
  location = "swedencentral"
  tags     = { example = "default" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-afw-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-mlz-afw-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.0.0.0/24"] }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "firewall_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "AzureFirewallSubnet"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = {
      addressPrefixes = ["10.0.0.0/26"]
    }
  }

  response_export_values = []
}

resource "azapi_resource" "workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = "log-mlz-afw-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

module "azure_firewall" {
  source = "../../"

  name      = "afw-mlz-afw-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  virtual_network = {
    subnet_id = azapi_resource.firewall_subnet.id
    public_ip = { name = "pip-mlz-afw-${random_string.suffix.result}" }
  }
  firewall_policy = {
    name = "afwp-mlz-afw-${random_string.suffix.result}"
    dns  = { proxy_enabled = true }
  }
  ip_groups = {
    spokes = { name = "ipg-mlz-afw-spokes-${random_string.suffix.result}", ip_addresses = ["10.1.0.0/16"] }
  }
  rule_collection_groups = {
    platform = {
      priority = 200
      network_rule_collections = {
        dns = {
          priority = 300
          action   = "Allow"
          rules = {
            spokes-to-azure-dns = {
              description           = "DNS from the spokes through the firewall's DNS proxy"
              protocols             = ["UDP", "TCP"]
              source_ip_groups      = ["spokes"]
              destination_addresses = ["10.0.0.4"]
              destination_ports     = ["53"]
            }
          }
        }
      }
      application_rule_collections = {
        updates = {
          priority = 400
          action   = "Allow"
          rules = {
            windows-update = {
              source_ip_groups      = ["spokes"]
              protocols             = [{ type = "Https", port = 443 }, { type = "Http", port = 80 }]
              destination_fqdn_tags = ["WindowsUpdate"]
            }
          }
        }
      }
    }
  }
  diagnostic_settings = {
    workspace = {
      workspace_resource_id = azapi_resource.workspace.id
      logs                  = [{ category_group = "allLogs" }]
      metrics               = [{ category = "AllMetrics" }]
    }
  }
  tags = local.tags
}
