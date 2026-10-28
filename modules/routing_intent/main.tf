resource "azapi_resource" "this" {
  type      = var.resource_types.network_virtual_hubs_routing_intent
  name      = var.name
  parent_id = var.parent_id
  body = {
    properties = {
      routingPolicies = [for name, policy in var.routing_policies : {
        name         = name
        destinations = policy.destinations
        nextHop      = policy.next_hop_id
      }]
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_virtual_hubs_routing_intent) > 0 ? var.ignore_body_changes.network_virtual_hubs_routing_intent : null
  # Azure refuses parallel writes to one hub's children (AnotherOperationInProgress).
  locks                            = [var.parent_id]
  replace_triggers_external_values = var.replace_triggers
  response_export_values           = []
  retry                            = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
