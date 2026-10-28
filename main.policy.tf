module "firewall_policy" {
  source = "./modules/firewall_policy"
  count  = var.firewall_policy == null ? 0 : 1

  name                          = var.firewall_policy.name
  parent_id                     = var.parent_id
  location                      = var.location
  sku_tier                      = var.sku_tier
  base_policy_id                = var.firewall_policy.base_policy_id
  threat_intelligence_mode      = var.firewall_policy.threat_intelligence_mode
  threat_intelligence_allowlist = var.firewall_policy.threat_intelligence_allowlist
  dns                           = var.firewall_policy.dns
  snat                          = var.firewall_policy.snat
  sql_redirect_allowed          = var.firewall_policy.sql_redirect_allowed
  explicit_proxy                = var.firewall_policy.explicit_proxy
  insights                      = var.firewall_policy.insights
  intrusion_detection = var.firewall_policy.intrusion_detection == null ? null : merge(var.firewall_policy.intrusion_detection, {
    traffic_bypass = { for name, bypass in var.firewall_policy.intrusion_detection.traffic_bypass : name => merge(bypass, {
      source_ip_groups      = [for group in bypass.source_ip_groups : try(module.ip_group[group].resource_id, group)]
      destination_ip_groups = [for group in bypass.destination_ip_groups : try(module.ip_group[group].resource_id, group)]
    }) }
  })
  tls_certificate    = var.firewall_policy.tls_certificate
  managed_identities = var.firewall_policy.managed_identities
  lock               = var.firewall_policy.lock
  role_assignments   = var.firewall_policy.role_assignments
  # Azure applies the policy's lock to its rule collection groups too.
  lock_dependencies   = { for name, group in module.rule_collection_group : name => group.lock_dependency }
  tags                = var.tags
  resource_types      = var.resource_types.network_firewall_policies
  ignore_body_changes = var.ignore_body_changes.network_firewall_policies
  retry               = var.retry
  timeouts            = var.timeouts
}
