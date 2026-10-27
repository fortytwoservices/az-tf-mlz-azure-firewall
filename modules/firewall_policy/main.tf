resource "azapi_resource" "this" {
  type      = var.resource_types.network_firewall_policies
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  # Every setting is sent, empty or null when unset: azapi compares only the keys in the body, so a setting
  # left out would stay in Azure after it is removed here (checked in the sandbox, 2026-10-27).
  body = {
    properties = {
      sku                  = { tier = var.sku_tier }
      basePolicy           = var.base_policy_id == null ? null : { id = var.base_policy_id }
      threatIntelMode      = var.threat_intelligence_mode
      threatIntelWhitelist = { ipAddresses = var.threat_intelligence_allowlist.ip_addresses, fqdns = var.threat_intelligence_allowlist.fqdns }
      # Basic rejects DNS settings even when empty (FirewallPolicyHigherTierOnlyProperties).
      dnsSettings = var.sku_tier == "Basic" ? null : {
        enableProxy                 = var.dns.proxy_enabled
        servers                     = var.dns.servers
        requireProxyForNetworkRules = var.dns.require_proxy_for_network_rules
      }
      snat = {
        privateRanges          = var.snat.private_ranges
        autoLearnPrivateRanges = var.snat.auto_learn_private_ranges_enabled ? "Enabled" : "Disabled"
      }
      sql = { allowSqlRedirect = var.sql_redirect_allowed }
      explicitProxy = var.explicit_proxy == null ? null : {
        enableExplicitProxy = var.explicit_proxy.enabled
        httpPort            = var.explicit_proxy.http_port
        httpsPort           = var.explicit_proxy.https_port
        enablePacFile       = var.explicit_proxy.pac_file_enabled
        pacFilePort         = var.explicit_proxy.pac_file_port
        pacFile             = var.explicit_proxy.pac_file
      }
      insights = var.insights == null ? null : {
        isEnabled     = var.insights.enabled
        retentionDays = var.insights.retention_in_days
        logAnalyticsResources = {
          defaultWorkspaceId = { id = var.insights.default_log_analytics_workspace_id }
          workspaces         = [for region, workspace_id in var.insights.log_analytics_workspaces : { region = region, workspaceId = { id = workspace_id } }]
        }
      }
      intrusionDetection = var.intrusion_detection == null ? null : {
        mode = var.intrusion_detection.mode
        configuration = {
          signatureOverrides = [for id, mode in var.intrusion_detection.signature_overrides : { id = id, mode = mode }]
          bypassTrafficSettings = [for name, bypass in var.intrusion_detection.traffic_bypass : {
            name                 = name
            description          = bypass.description
            protocol             = bypass.protocol
            sourceAddresses      = bypass.source_addresses
            sourceIpGroups       = bypass.source_ip_groups
            destinationAddresses = bypass.destination_addresses
            destinationIpGroups  = bypass.destination_ip_groups
            destinationPorts     = bypass.destination_ports
          }]
          privateRanges = var.intrusion_detection.private_ranges
        }
      }
      transportSecurity = var.tls_certificate == null ? null : {
        certificateAuthority = { keyVaultSecretId = var.tls_certificate.key_vault_secret_id, name = var.tls_certificate.name }
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_firewall_policies) > 0 ? var.ignore_body_changes.network_firewall_policies : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  # Left out when there is none, which removes an identity from the policy (checked in the sandbox).
  dynamic "identity" {
    for_each = local.identity_type == null ? [] : [local.identity_type]
    content {
      type         = identity.value
      identity_ids = sort(tolist(var.managed_identities.user_assigned_resource_ids))
    }
  }

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
    precondition {
      condition     = var.tls_certificate == null || length(var.managed_identities.user_assigned_resource_ids) > 0
      error_message = "TLS inspection reads its certificate from Key Vault with a user-assigned identity: set `managed_identities.user_assigned_resource_ids`."
    }
  }
}
