# Reads the firewall policy straight from Azure.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "firewall_policy_id" {
  type = string
}

data "azapi_resource" "firewall_policy" {
  type                   = "Microsoft.Network/firewallPolicies@2025-07-01"
  resource_id            = var.firewall_policy_id
  response_export_values = ["identity", "properties"]
}

output "settings" {
  description = "The settings this module sends, as Azure returns them."
  value = {
    identity_type  = try(data.azapi_resource.firewall_policy.output.identity.type, null)
    allowlist_ips  = try(data.azapi_resource.firewall_policy.output.properties.threatIntelWhitelist.ipAddresses, [])
    dns_proxy      = try(data.azapi_resource.firewall_policy.output.properties.dnsSettings.enableProxy, false)
    dns_servers    = try(data.azapi_resource.firewall_policy.output.properties.dnsSettings.servers, [])
    snat_ranges    = try(data.azapi_resource.firewall_policy.output.properties.snat.privateRanges, null)
    explicit_proxy = try(data.azapi_resource.firewall_policy.output.properties.explicitProxy.enableExplicitProxy, null)
    insights       = try(data.azapi_resource.firewall_policy.output.properties.insights.isEnabled, null)
    intrusion_mode = try(data.azapi_resource.firewall_policy.output.properties.intrusionDetection.mode, null)
    tier           = data.azapi_resource.firewall_policy.output.properties.sku.tier
  }
}
