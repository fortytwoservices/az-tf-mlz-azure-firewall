resource "azapi_resource" "this" {
  type      = var.resource_types.network_ip_groups
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  body = {
    properties = {
      # Sorted, so the same addresses in another order change nothing.
      ipAddresses = sort(var.ip_addresses)
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_ip_groups) > 0 ? var.ignore_body_changes.network_ip_groups : null
  # Azure updates up to 20 IP groups in parallel, also together with the firewall and its policies
  # (Microsoft Learn, "IP Groups in Azure Firewall"), so their writes are not serialised.
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    # A new name replaces the group. Azure deletes an IP group only once no rule uses it (Learn, "IP
    # Groups in Azure Firewall policy"), so the new one is created first, the rules move to it, and the old
    # one goes last.
    create_before_destroy = true
  }
}
