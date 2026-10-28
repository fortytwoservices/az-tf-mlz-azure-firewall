module "rule_collection_group" {
  source   = "./modules/rule_collection_group"
  for_each = var.rule_collection_groups

  name                         = each.key
  parent_id                    = local.firewall_policy_id
  priority                     = each.value.priority
  application_rule_collections = local.rule_collection_groups[each.key].application_rule_collections
  network_rule_collections     = local.rule_collection_groups[each.key].network_rule_collections
  nat_rule_collections         = local.rule_collection_groups[each.key].nat_rule_collections
  resource_types               = var.resource_types.network_firewall_policies_rule_collection_groups
  ignore_body_changes          = var.ignore_body_changes.network_firewall_policies_rule_collection_groups
  retry                        = var.retry
  timeouts                     = var.timeouts
}
