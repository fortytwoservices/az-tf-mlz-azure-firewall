# Reads the IP group straight from Azure.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "ip_group_id" {
  type = string
}

data "azapi_resource" "ip_group" {
  type                   = "Microsoft.Network/ipGroups@2025-07-01"
  resource_id            = var.ip_group_id
  response_export_values = ["properties.ipAddresses"]
}

output "ip_addresses" {
  value = data.azapi_resource.ip_group.output.properties.ipAddresses
}
