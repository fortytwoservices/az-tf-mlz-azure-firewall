output "firewall_policy_resource_id" {
  description = "Resource ID of the firewall's policy, created by the module or given."
  value       = local.firewall_policy_id
}

output "ip_group_resource_ids" {
  description = "Resource IDs of the IP groups the module creates, by key."
  value       = { for key, group in module.ip_group : key => group.resource_id }
}

output "name" {
  description = "Name of the firewall."
  value       = azapi_resource.this.name
}

output "private_ip_address" {
  description = "Private IP address of the firewall in `AzureFirewallSubnet`, the next hop for routes to it."
  value       = azapi_resource.this.output.properties.ipConfigurations[0].properties.privateIPAddress
}

output "public_ip_address_ids" {
  description = "Resource IDs of the firewall's public IP addresses, created or given, by IP configuration name (the management one included)."
  value       = local.public_ip_ids
}

output "public_ip_addresses" {
  description = "IP addresses of the public IP addresses the module creates, by IP configuration name."
  value       = { for name, public_ip in module.public_ip : name => public_ip.ip_address }
}

output "resource_id" {
  description = "Resource ID of the firewall."
  value       = azapi_resource.this.id
}

output "rule_collection_group_resource_ids" {
  description = "Resource IDs of the rule collection groups, by name."
  value       = { for name, group in module.rule_collection_group : name => group.resource_id }
}
