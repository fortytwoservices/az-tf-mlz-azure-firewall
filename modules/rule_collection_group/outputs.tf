output "lock_dependency" {
  description = "Changes whenever the group is created, replaced or changed. The caller passes it in the policy's `lock_dependencies`: Azure applies the policy's lock to the group too, and a `ReadOnly` lock also blocks updating it in place, which keeps its ID."
  value       = sha256(jsonencode([azapi_resource.this.id, azapi_resource.this.body]))
}

output "name" {
  description = "Name of the rule collection group."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the rule collection group."
  value       = azapi_resource.this.id
}
