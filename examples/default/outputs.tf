output "private_ip_address" {
  description = "Private IP address of the firewall, the next hop for the spokes' routes."
  value       = module.azure_firewall.private_ip_address
}

output "public_ip_addresses" {
  description = "The firewall's public IP addresses, by IP configuration name."
  value       = module.azure_firewall.public_ip_addresses
}

output "resource_id" {
  description = "Resource ID of the firewall."
  value       = module.azure_firewall.resource_id
}
