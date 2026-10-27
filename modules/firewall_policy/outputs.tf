output "name" {
  description = "Name of the firewall policy."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the firewall policy."
  value       = azapi_resource.this.id
}
