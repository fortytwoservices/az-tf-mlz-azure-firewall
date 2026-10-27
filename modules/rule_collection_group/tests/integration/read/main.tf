# Reads the rule collection group straight from Azure.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "rule_collection_group_id" {
  type = string
}

data "azapi_resource" "rule_collection_group" {
  type                   = "Microsoft.Network/firewallPolicies/ruleCollectionGroups@2025-07-01"
  resource_id            = var.rule_collection_group_id
  response_export_values = ["properties.ruleCollections"]
}

output "rules" {
  description = "Rule descriptions, by collection and rule name."
  value = {
    for collection in data.azapi_resource.rule_collection_group.output.properties.ruleCollections : collection.name => {
      for rule in collection.rules : rule.name => try(rule.description, null)
    }
  }
}
