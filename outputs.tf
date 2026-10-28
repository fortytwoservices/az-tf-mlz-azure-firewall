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

output "hub_public_ip_addresses" {
  description = "The public IP addresses Azure assigns to a firewall in a Virtual WAN hub; empty in a VNet hub."
  value       = var.virtual_hub == null ? [] : [for address in try(azapi_resource.this.output.properties.hubIPAddresses.publicIPs.addresses, []) : address.address]
}

output "private_ip_address" {
  description = "Private IP address of the firewall, the next hop for routes to it: in `AzureFirewallSubnet` for a VNet hub, in the hub's address space for a Virtual WAN hub."
  value       = var.virtual_hub == null ? azapi_resource.this.output.properties.ipConfigurations[0].properties.privateIPAddress : azapi_resource.this.output.properties.hubIPAddresses.privateIPAddress
}

output "public_ip_address_ids" {
  description = "Resource IDs of the firewall's public IP addresses in a VNet hub, created or given, by IP configuration name (the management one included); empty in a Virtual WAN hub."
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

output "routing_intent_resource_id" {
  description = "Resource ID of the hub's routing intent, when the module manages it; otherwise null."
  value       = one(module.routing_intent[*].resource_id)
}

output "rule_collection_group_resource_ids" {
  description = "Resource IDs of the rule collection groups, by name."
  value       = { for name, group in module.rule_collection_group : name => group.resource_id }
}
