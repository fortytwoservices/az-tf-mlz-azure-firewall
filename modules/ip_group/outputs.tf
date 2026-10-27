output "name" {
  description = "Name of the IP group."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the IP group."
  value       = azapi_resource.this.id
}
