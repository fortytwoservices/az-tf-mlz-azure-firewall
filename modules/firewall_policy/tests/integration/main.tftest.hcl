# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/firewall_policy
# Proves what mocks cannot: the default API version takes every Standard setting and the always-sent
# empty sections on Basic, Standard and Premium; clearing the settings and the identity under the lock
# reaches Azure; Premium takes intrusion detection. TLS inspection needs a Key Vault certificate and is
# not deployed here (its body is checked against the schema and in the unit tests).

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "standard_with_every_setting" {
  variables {
    name                          = "afwp-mlz-it-${run.setup.suffix}"
    parent_id                     = run.setup.resource_group_id
    location                      = run.setup.location
    threat_intelligence_mode      = "Deny"
    threat_intelligence_allowlist = { ip_addresses = ["203.0.113.5"], fqdns = ["allowed.example.com"] }
    dns                           = { proxy_enabled = true, servers = ["168.63.129.16"] }
    snat                          = { private_ranges = ["192.168.0.0/16", "10.0.0.0/8"] }
    sql_redirect_allowed          = true
    explicit_proxy                = { http_port = 8080, https_port = 8443 }
    insights                      = { retention_in_days = 30, default_log_analytics_workspace_id = run.setup.workspace_id }
    managed_identities            = { user_assigned_resource_ids = [run.setup.identity_id] }
    lock                          = { kind = "CanNotDelete" }
  }
}

run "every_setting_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    firewall_policy_id = run.standard_with_every_setting.resource_id
  }

  assert {
    condition = jsonencode(output.settings) == jsonencode({
      identity_type  = "UserAssigned"
      allowlist_ips  = ["203.0.113.5"]
      dns_proxy      = true
      dns_servers    = ["168.63.129.16"]
      snat_ranges    = ["192.168.0.0/16", "10.0.0.0/8"]
      explicit_proxy = true
      insights       = true
      intrusion_mode = null
      tier           = "Standard"
    })
    error_message = "Azure should have every setting, got ${jsonencode(output.settings)}."
  }
}

run "clear_settings_under_lock" {
  variables {
    name      = "afwp-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    lock      = { kind = "CanNotDelete" }
  }
}

run "cleared_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    firewall_policy_id = run.clear_settings_under_lock.resource_id
  }

  assert {
    condition = jsonencode(output.settings) == jsonencode({
      identity_type  = null
      allowlist_ips  = []
      dns_proxy      = false
      dns_servers    = []
      snat_ranges    = null
      explicit_proxy = null
      insights       = null
      intrusion_mode = null
      tier           = "Standard"
    })
    error_message = "Azure should have every setting and the identity removed, got ${jsonencode(output.settings)}."
  }
}

run "premium_with_intrusion_detection" {
  variables {
    name      = "afwp-mlz-it-${run.setup.suffix}-premium"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku_tier  = "Premium"
    intrusion_detection = {
      mode                = "Alert"
      signature_overrides = { "2024897" = "Off" }
      traffic_bypass = {
        backup = { protocol = "TCP", source_addresses = ["10.0.0.0/24"], destination_addresses = ["10.1.0.0/24"], destination_ports = ["445"] }
      }
    }
  }
}

run "premium_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    firewall_policy_id = run.premium_with_intrusion_detection.resource_id
  }

  assert {
    condition     = output.settings.tier == "Premium" && output.settings.intrusion_mode == "Alert"
    error_message = "Azure should have the Premium tier with intrusion detection, got ${jsonencode(output.settings)}."
  }
}

run "basic" {
  variables {
    name      = "afwp-mlz-it-${run.setup.suffix}-basic"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku_tier  = "Basic"
  }
}
