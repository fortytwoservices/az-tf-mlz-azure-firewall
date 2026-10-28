module "routing_intent" {
  source = "./modules/routing_intent"
  count  = var.virtual_hub == null ? 0 : var.virtual_hub.routing_intent == null ? 0 : 1

  name      = var.virtual_hub.routing_intent.name
  parent_id = var.virtual_hub.virtual_hub_id
  routing_policies = merge(
    var.virtual_hub.routing_intent.internet_traffic ? { InternetTraffic = { destinations = ["Internet"], next_hop_id = azapi_resource.this.id } } : {},
    var.virtual_hub.routing_intent.private_traffic ? { PrivateTrafficPolicy = { destinations = ["PrivateTraffic"], next_hop_id = azapi_resource.this.id } } : {},
  )
  replace_triggers    = local.firewall_replace_triggers
  resource_types      = var.resource_types.network_virtual_hubs_routing_intent
  ignore_body_changes = var.ignore_body_changes.network_virtual_hubs_routing_intent
  retry               = var.retry
  timeouts            = var.timeouts
}
