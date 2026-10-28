resource "azapi_resource" "this" {
  type      = var.resource_types.network_firewall_policies_rule_collection_groups
  name      = var.name
  parent_id = var.parent_id
  body = {
    properties = {
      priority = var.priority
      # Every optional field is sent, null or empty when unset, so that removing it reaches Azure: azapi
      # compares only the keys in the body, inside list items too.
      ruleCollections = concat(
        [for name, collection in var.application_rule_collections : {
          ruleCollectionType = "FirewallPolicyFilterRuleCollection"
          name               = name
          priority           = collection.priority
          action             = { type = collection.action }
          rules = [for rule_name, rule in collection.rules : {
            ruleType             = "ApplicationRule"
            name                 = rule_name
            description          = rule.description
            sourceAddresses      = rule.source_addresses
            sourceIpGroups       = rule.source_ip_groups
            protocols            = [for protocol in rule.protocols : { protocolType = protocol.type, port = protocol.port }]
            targetFqdns          = rule.destination_fqdns
            fqdnTags             = rule.destination_fqdn_tags
            targetUrls           = rule.destination_urls
            destinationAddresses = rule.destination_addresses
            webCategories        = rule.web_categories
            terminateTLS         = rule.terminate_tls
            httpHeadersToInsert  = [for header, value in rule.http_headers : { headerName = header, headerValue = value }]
          }]
        }],
        [for name, collection in var.network_rule_collections : {
          ruleCollectionType = "FirewallPolicyFilterRuleCollection"
          name               = name
          priority           = collection.priority
          action             = { type = collection.action }
          rules = [for rule_name, rule in collection.rules : {
            ruleType             = "NetworkRule"
            name                 = rule_name
            description          = rule.description
            ipProtocols          = rule.protocols
            sourceAddresses      = rule.source_addresses
            sourceIpGroups       = rule.source_ip_groups
            destinationAddresses = rule.destination_addresses
            destinationIpGroups  = rule.destination_ip_groups
            destinationFqdns     = rule.destination_fqdns
            destinationPorts     = rule.destination_ports
          }]
        }],
        [for name, collection in var.nat_rule_collections : {
          ruleCollectionType = "FirewallPolicyNatRuleCollection"
          name               = name
          priority           = collection.priority
          action             = { type = "Dnat" } # Azure returns this casing; the schema lists DNAT
          rules = [for rule_name, rule in collection.rules : {
            ruleType             = "NatRule"
            name                 = rule_name
            description          = rule.description
            ipProtocols          = rule.protocols
            sourceAddresses      = rule.source_addresses
            sourceIpGroups       = rule.source_ip_groups
            destinationAddresses = [rule.destination_address]
            destinationPorts     = rule.destination_ports
            translatedAddress    = rule.translated_address
            translatedFqdn       = rule.translated_fqdn
            translatedPort       = tostring(rule.translated_port) # ARM takes a string
          }]
        }],
      )
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_firewall_policies_rule_collection_groups) > 0 ? var.ignore_body_changes.network_firewall_policies_rule_collection_groups : null
  # Azure refuses parallel writes of rule collection groups to one policy (AnotherOperationInProgress).
  locks                  = [var.parent_id]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  # Not create_before_destroy, unlike the policy and IP groups: Terraform deletes such a resource only after
  # its dependents are updated, and the policy's lock is one (through lock_dependency), so the old group
  # would be deleted under the lock again (ScopeLocked, integration test 2026-10-28). Replacing the groups
  # (a renamed or another policy) therefore deletes the old ones before the firewall switches policy.
}
