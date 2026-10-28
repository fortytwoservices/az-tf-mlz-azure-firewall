locals {
  # Firewall policies take user-assigned identities only (CannotSetResourceIdentity, 2026-10-28).
  identity_type = length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : null
}
