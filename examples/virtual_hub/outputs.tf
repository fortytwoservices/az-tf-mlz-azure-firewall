output "hub_public_ip_addresses" {
  description = "The public IP addresses Azure assigned to the firewall."
  value       = module.azure_firewall.hub_public_ip_addresses
}

output "private_ip_address" {
  description = "Private IP address of the firewall in the hub."
  value       = module.azure_firewall.private_ip_address
}

output "resource_id" {
  description = "Resource ID of the firewall."
  value       = module.azure_firewall.resource_id
}
