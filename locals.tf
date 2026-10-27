locals {
  firewall_policy_id = var.firewall_policy_id != null ? var.firewall_policy_id : module.firewall_policy[0].resource_id
  # Public IP addresses by the IP configuration that holds them.
  public_ips = merge(
    var.virtual_network.public_ip == null ? {} : { (var.virtual_network.ip_configuration_name) = var.virtual_network.public_ip },
    var.virtual_network.additional_public_ips,
    var.virtual_network.management == null ? {} : { (var.virtual_network.management.ip_configuration_name) = var.virtual_network.management.public_ip },
  )
  public_ip_ids = { for name, public_ip in local.public_ips : name => public_ip.name != null ? module.public_ip[name].resource_id : public_ip.resource_id }
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
}
