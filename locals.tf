locals {
  # Chosen by the same test as the policy module's count, so an existing policy ID that is unknown until
  # apply never makes Terraform index a policy module that does not exist.
  firewall_policy_id = var.firewall_policy == null ? var.firewall_policy_id : module.firewall_policy[0].resource_id
  # The public IP addresses the module creates, by the IP configuration that holds them. Only the
  # presence of an object decides membership, so a name unknown until apply cannot make the keys unknown.
  # A firewall in a Virtual WAN hub has Azure-managed public IP addresses only.
  created_public_ips = var.virtual_network == null ? {} : merge(
    var.virtual_network.public_ip == null ? {} : { (var.virtual_network.ip_configuration_name) = var.virtual_network.public_ip },
    var.virtual_network.additional_public_ips,
    var.virtual_network.management == null ? {} : var.virtual_network.management.public_ip == null ? {} : { (var.virtual_network.management.ip_configuration_name) = var.virtual_network.management.public_ip },
  )
  # Every public IP address, created or existing, by IP configuration.
  public_ip_ids = var.virtual_network == null ? {} : merge(
    { for name, public_ip in module.public_ip : name => public_ip.resource_id },
    var.virtual_network.public_ip_resource_id == null ? {} : { (var.virtual_network.ip_configuration_name) = var.virtual_network.public_ip_resource_id },
    var.virtual_network.additional_public_ip_resource_ids,
    var.virtual_network.management == null ? {} : var.virtual_network.management.public_ip_resource_id == null ? {} : { (var.virtual_network.management.ip_configuration_name) = var.virtual_network.management.public_ip_resource_id },
  )
  # IP group keys in rules become the IDs of the groups this module creates; anything else is passed on as
  # an ID.
  rule_collection_groups = { for group_name, group in var.rule_collection_groups : group_name => {
    application_rule_collections = { for name, collection in group.application_rule_collections : name => merge(collection, {
      rules = { for rule_name, rule in collection.rules : rule_name => merge(rule, {
        source_ip_groups = [for ip_group in rule.source_ip_groups : try(module.ip_group[ip_group].resource_id, ip_group)]
      }) }
    }) }
    network_rule_collections = { for name, collection in group.network_rule_collections : name => merge(collection, {
      rules = { for rule_name, rule in collection.rules : rule_name => merge(rule, {
        source_ip_groups      = [for ip_group in rule.source_ip_groups : try(module.ip_group[ip_group].resource_id, ip_group)]
        destination_ip_groups = [for ip_group in rule.destination_ip_groups : try(module.ip_group[ip_group].resource_id, ip_group)]
      }) }
    }) }
    nat_rule_collections = { for name, collection in group.nat_rule_collections : name => merge(collection, {
      rules = { for rule_name, rule in collection.rules : rule_name => merge(rule, {
        source_ip_groups = [for ip_group in rule.source_ip_groups : try(module.ip_group[ip_group].resource_id, ip_group)]
      }) }
    }) }
  } }
  zones = var.zones == null ? null : sort(distinct(var.zones))
  # The firewall's replacement triggers (main.tf), also the routing intent's: a replaced firewall keeps its
  # resource ID, so the routing intent must be replaced with it, deleted before the old firewall and
  # created after the new one, rather than left pointing at a firewall being deleted.
  firewall_replace_triggers = {
    basic      = var.sku_tier == "Basic"
    management = var.virtual_network == null ? false : var.virtual_network.management != null
    subnet_id  = var.virtual_network != null ? lower(var.virtual_network.subnet_id) : var.virtual_hub == null ? null : lower(var.virtual_hub.virtual_hub_id)
    zones      = local.zones
  }
}
