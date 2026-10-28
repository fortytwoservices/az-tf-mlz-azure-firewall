mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/firewallPolicies/afwp-test"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  location  = "norwayeast"
  name      = "afwp-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/firewallPolicies@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The policy should use the default resource type, name, parent_id and location."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body.properties) == jsonencode({
      sku                  = { tier = "Standard" }
      basePolicy           = null
      threatIntelMode      = "Alert"
      threatIntelWhitelist = { ipAddresses = [], fqdns = [] }
      dnsSettings          = { enableProxy = false, servers = [], requireProxyForNetworkRules = null }
      snat                 = { privateRanges = null, autoLearnPrivateRanges = "Disabled" }
      sql                  = { allowSqlRedirect = false }
      explicitProxy        = null
      insights             = null
      intrusionDetection   = null
      transportSecurity    = null
    })
    error_message = "Every setting should be sent, empty or null by default, so removing one reaches Azure."
  }
  assert {
    condition     = length(azapi_resource.this.identity) == 0 && azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "No identity, retry, timeouts or tags should be set by default."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) == 0
    error_message = "No lock or role assignment should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name
    error_message = "resource_id and name should come from the policy."
  }
}

run "standard_settings" {
  command = apply

  variables {
    base_policy_id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/firewallPolicies/afwp-base"
    threat_intelligence_mode      = "Deny"
    threat_intelligence_allowlist = { ip_addresses = ["203.0.113.5"], fqdns = ["allowed.example.com"] }
    dns                           = { proxy_enabled = true, servers = ["168.63.129.16"], require_proxy_for_network_rules = true }
    snat                          = { private_ranges = ["10.0.0.0/8", "100.64.0.0/10"], auto_learn_private_ranges_enabled = true }
    sql_redirect_allowed          = true
    explicit_proxy                = { http_port = 8080, https_port = 8443, pac_file_enabled = true, pac_file_port = 8081, pac_file = "https://example.blob.core.windows.net/pac/proxy.pac" }
    insights = {
      retention_in_days                  = 30
      default_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-default"
      log_analytics_workspaces           = { norwayeast = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-nwe" }
    }
    lock = { kind = "CanNotDelete" }
  }

  assert {
    condition     = azapi_resource.this.body.properties.basePolicy.id == var.base_policy_id && azapi_resource.this.body.properties.threatIntelMode == "Deny" && azapi_resource.this.body.properties.threatIntelWhitelist.fqdns == tolist(["allowed.example.com"])
    error_message = "The base policy and threat intelligence settings should map to the body."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.body.properties.dnsSettings) == jsonencode({ enableProxy = true, servers = ["168.63.129.16"], requireProxyForNetworkRules = true })
    error_message = "The DNS settings should map to the body."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.body.properties.snat) == jsonencode({ privateRanges = ["10.0.0.0/8", "100.64.0.0/10"], autoLearnPrivateRanges = "Enabled" }) && azapi_resource.this.body.properties.sql.allowSqlRedirect
    error_message = "The SNAT and SQL settings should map to the body."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.body.properties.explicitProxy) == jsonencode({ enableExplicitProxy = true, httpPort = 8080, httpsPort = 8443, enablePacFile = true, pacFilePort = 8081, pacFile = "https://example.blob.core.windows.net/pac/proxy.pac" })
    error_message = "The explicit proxy settings should map to the body, enabled by default."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body.properties.insights) == jsonencode({
      isEnabled     = true
      retentionDays = 30
      logAnalyticsResources = {
        defaultWorkspaceId = { id = var.insights.default_log_analytics_workspace_id }
        workspaces         = [{ region = "norwayeast", workspaceId = { id = var.insights.log_analytics_workspaces.norwayeast } }]
      }
    })
    error_message = "The insights settings should map to the body, enabled by default."
  }
  assert {
    condition     = module.interfaces.lock_resource_id != null
    error_message = "The lock should be created through az-tf-mlz-interfaces."
  }
}

run "premium_settings" {
  command = apply

  variables {
    sku_tier = "Premium"
    intrusion_detection = {
      mode                = "Deny"
      signature_overrides = { "2024897" = "Off" }
      traffic_bypass = {
        backup = { protocol = "TCP", source_addresses = ["10.0.0.0/24"], destination_addresses = ["10.1.0.0/24"], destination_ports = ["445"] }
      }
      private_ranges = ["10.0.0.0/8"]
    }
    tls_certificate    = { key_vault_secret_id = "https://kv-test.vault.azure.net/secrets/interca", name = "interca" }
    managed_identities = { user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"] }
  }

  assert {
    condition = jsonencode(azapi_resource.this.body.properties.intrusionDetection) == jsonencode({
      mode = "Deny"
      configuration = {
        signatureOverrides = [{ id = "2024897", mode = "Off" }]
        bypassTrafficSettings = [{
          name                 = "backup"
          description          = null
          protocol             = "TCP"
          sourceAddresses      = ["10.0.0.0/24"]
          sourceIpGroups       = []
          destinationAddresses = ["10.1.0.0/24"]
          destinationIpGroups  = []
          destinationPorts     = ["445"]
        }]
        privateRanges = ["10.0.0.0/8"]
      }
    })
    error_message = "The intrusion detection settings should map to the body."
  }
  assert {
    condition     = azapi_resource.this.body.properties.transportSecurity.certificateAuthority.keyVaultSecretId == var.tls_certificate.key_vault_secret_id && azapi_resource.this.body.properties.sku.tier == "Premium"
    error_message = "The TLS certificate and the tier should map to the body."
  }
  assert {
    condition     = azapi_resource.this.identity[0].type == "UserAssigned" && azapi_resource.this.identity[0].identity_ids == tolist(var.managed_identities.user_assigned_resource_ids)
    error_message = "A user-assigned identity should be set on the policy."
  }
}

run "system_and_user_assigned_identity" {
  command = apply

  variables {
    managed_identities = {
      system_assigned            = true
      user_assigned_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"]
    }
  }

  assert {
    condition     = azapi_resource.this.identity[0].type == "SystemAssigned, UserAssigned"
    error_message = "Both identity kinds should combine into one identity type."
  }
}

run "overrides" {
  command = apply

  variables {
    resource_types      = { network_firewall_policies = "Microsoft.Network/firewallPolicies@2025-05-01" }
    ignore_body_changes = { network_firewall_policies = ["properties.threatIntelMode"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "15m" }
    tags                = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/firewallPolicies@2025-05-01" && azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "resource_types and tags should reach the policy."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "15m"
    error_message = "retry and timeouts should reach the policy."
  }
}

run "tls_without_identity" {
  command = plan

  variables {
    sku_tier        = "Premium"
    tls_certificate = { key_vault_secret_id = "https://kv-test.vault.azure.net/secrets/interca", name = "interca" }
  }

  expect_failures = [azapi_resource.this]
}

run "basic" {
  command = apply

  variables {
    sku_tier = "Basic"
  }

  assert {
    condition     = azapi_resource.this.body.properties.sku.tier == "Basic" && azapi_resource.this.body.properties.dnsSettings == null
    error_message = "A Basic policy should send no DNS settings, which Azure rejects on Basic even when empty."
  }
}

run "dns_servers_on_basic" {
  command = plan

  variables {
    sku_tier = "Basic"
    dns      = { servers = ["168.63.129.16"] }
  }

  expect_failures = [var.dns]
}

run "intrusion_detection_on_standard" {
  command = plan

  variables {
    intrusion_detection = { mode = "Alert" }
  }

  expect_failures = [var.intrusion_detection]
}

run "tls_on_standard" {
  command = plan

  variables {
    tls_certificate = { key_vault_secret_id = "https://kv-test.vault.azure.net/secrets/interca", name = "interca" }
  }

  expect_failures = [var.tls_certificate]
}

run "explicit_proxy_without_ports" {
  command = plan

  variables {
    explicit_proxy = { http_port = 8080 }
  }

  expect_failures = [var.explicit_proxy]
}

run "iana_keyword_in_snat_ranges" {
  command = plan

  variables {
    snat = { private_ranges = ["IANAPrivateRanges", "100.64.0.0/10"] }
  }

  expect_failures = [var.snat]
}

run "invalid_threat_intelligence_mode" {
  command = plan

  variables {
    threat_intelligence_mode = "Block"
  }

  expect_failures = [var.threat_intelligence_mode]
}

run "invalid_sku_tier" {
  command = plan

  variables {
    sku_tier = "Free"
  }

  expect_failures = [var.sku_tier]
}

run "invalid_workspace_id" {
  command = plan

  variables {
    insights = { default_log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test" }
  }

  expect_failures = [var.insights]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}
