# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/rule_collection_group
# Proves what mocks cannot: the default API version takes all three rule types, and removing a
# description, a rule and a collection reaches Azure (azapi compares only the keys in the body, so every
# field is sent). A clean second plan, including the DNAT action's casing, was checked with apply and plan
# (2026-10-27).

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name      = "rcg-mlz-it"
    parent_id = run.setup.firewall_policy_id
    priority  = 200
    application_rule_collections = {
      app = {
        priority = 300
        action   = "Allow"
        rules = {
          web = {
            description       = "Web"
            source_addresses  = ["10.0.0.0/24"]
            protocols         = [{ type = "Https", port = 443 }]
            destination_fqdns = ["www.example.com"]
          }
          updates = {
            source_addresses      = ["10.0.1.0/24"]
            protocols             = [{ type = "Https", port = 443 }, { type = "Http", port = 80 }]
            destination_fqdn_tags = ["WindowsUpdate"]
          }
        }
      }
    }
    network_rule_collections = {
      net = {
        priority = 400
        action   = "Deny"
        rules = {
          dns = {
            protocols             = ["UDP", "TCP"]
            source_addresses      = ["10.0.0.0/16"]
            destination_addresses = ["10.1.0.4"]
            destination_ports     = ["53"]
          }
        }
      }
    }
    nat_rule_collections = {
      dnat = {
        priority = 100
        rules = {
          rdp = {
            protocols           = ["TCP"]
            source_addresses    = ["*"]
            destination_address = "203.0.113.10"
            destination_ports   = ["3389"]
            translated_address  = "10.0.0.4"
            translated_port     = 3389
          }
        }
      }
    }
  }
}

run "remove_description_rule_and_collection" {
  variables {
    name      = "rcg-mlz-it"
    parent_id = run.setup.firewall_policy_id
    priority  = 200
    application_rule_collections = {
      app = {
        priority = 300
        action   = "Allow"
        rules = {
          web = {
            source_addresses  = ["10.0.0.0/24"]
            protocols         = [{ type = "Https", port = 443 }]
            destination_fqdns = ["www.example.com"]
          }
        }
      }
    }
    nat_rule_collections = {
      dnat = {
        priority = 100
        rules = {
          rdp = {
            protocols           = ["TCP"]
            source_addresses    = ["*"]
            destination_address = "203.0.113.10"
            destination_ports   = ["3389"]
            translated_address  = "10.0.0.4"
            translated_port     = 3389
          }
        }
      }
    }
  }
}

run "removals_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    rule_collection_group_id = run.remove_description_rule_and_collection.resource_id
  }

  assert {
    condition     = jsonencode(output.rules) == jsonencode({ app = { web = null }, dnat = { rdp = null } })
    error_message = "Azure should have the description, the updates rule and the net collection removed, got ${jsonencode(output.rules)}."
  }
}
