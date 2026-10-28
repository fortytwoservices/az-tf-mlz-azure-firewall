output "name" {
  description = "Name of the routing intent."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the routing intent."
  value       = azapi_resource.this.id
}
