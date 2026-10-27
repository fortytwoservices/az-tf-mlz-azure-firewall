mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/firewallPolicies/afwp-test/ruleCollectionGroups/rcg-test"
    }
  }
}

variables {
  name      = "rcg-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/firewallPolicies/afwp-test"
  priority  = 200
}

run "empty_group" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/firewallPolicies/ruleCollectionGroups@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id
    error_message = "The group should use the default resource type, name and parent_id."
  }
  assert {
    condition     = azapi_resource.this.body.properties.priority == 200 && length(azapi_resource.this.body.properties.ruleCollections) == 0
    error_message = "A group without collections should send its priority and an empty list."
  }
  assert {
    condition     = azapi_resource.this.locks == tolist([var.parent_id])
    error_message = "Writes should be serialised on the policy."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.retry.interval_seconds == 30 && azapi_resource.this.retry.max_interval_seconds == 300
    error_message = "The default retry should cover AnotherOperationInProgress."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && length(output.lock_dependency) == 64
    error_message = "resource_id, name and lock_dependency should come from the group."
  }
}

run "all_rule_types" {
  command = apply

  variables {
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
            http_headers      = { "X-Test" = "1" }
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
            protocols             = ["UDP"]
            source_ip_groups      = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ipGroups/ipg-test"]
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

  assert {
    condition     = jsonencode([for c in azapi_resource.this.body.properties.ruleCollections : c.name]) == jsonencode(["app", "net", "dnat"])
    error_message = "Collections should be sent application, network, then DNAT, each by key."
  }
  assert {
    condition     = azapi_resource.this.body.properties.ruleCollections[0].ruleCollectionType == "FirewallPolicyFilterRuleCollection" && azapi_resource.this.body.properties.ruleCollections[0].action.type == "Allow" && azapi_resource.this.body.properties.ruleCollections[0].priority == 300
    error_message = "An application collection should be a filter collection with its action and priority."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body.properties.ruleCollections[0].rules[0]) == jsonencode({
      ruleType             = "ApplicationRule"
      name                 = "web"
      description          = "Web"
      sourceAddresses      = ["10.0.0.0/24"]
      sourceIpGroups       = []
      protocols            = [{ protocolType = "Https", port = 443 }]
      targetFqdns          = ["www.example.com"]
      fqdnTags             = []
      targetUrls           = []
      destinationAddresses = []
      webCategories        = []
      terminateTLS         = false
      httpHeadersToInsert  = [{ headerName = "X-Test", headerValue = "1" }]
    })
    error_message = "An application rule should send every field, empty when unset, so removals reach Azure."
  }
  assert {
    condition     = azapi_resource.this.body.properties.ruleCollections[1].rules[0].ruleType == "NetworkRule" && azapi_resource.this.body.properties.ruleCollections[1].rules[0].ipProtocols == tolist(["UDP"]) && azapi_resource.this.body.properties.ruleCollections[1].rules[0].sourceIpGroups == tolist(["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ipGroups/ipg-test"]) && azapi_resource.this.body.properties.ruleCollections[1].rules[0].description == null
    error_message = "A network rule should map protocols and IP groups, with an unset description sent as null."
  }
  assert {
    condition     = azapi_resource.this.body.properties.ruleCollections[2].ruleCollectionType == "FirewallPolicyNatRuleCollection" && azapi_resource.this.body.properties.ruleCollections[2].action.type == "Dnat"
    error_message = "A DNAT collection should send the action in the casing Azure returns (Dnat), or every plan would change it."
  }
  assert {
    condition     = tolist(azapi_resource.this.body.properties.ruleCollections[2].rules[0].destinationAddresses) == tolist(["203.0.113.10"]) && azapi_resource.this.body.properties.ruleCollections[2].rules[0].translatedPort == "3389" && azapi_resource.this.body.properties.ruleCollections[2].rules[0].translatedFqdn == null
    error_message = "A DNAT rule should send one destination address and the translated port as a string."
  }
}

run "lock_dependency_changes_with_the_rules" {
  command = apply

  variables {
    priority = 201
  }

  # An update in place keeps the ID, and the policy's ReadOnly lock blocks it too.
  assert {
    condition     = output.resource_id == run.empty_group.resource_id && output.lock_dependency != run.empty_group.lock_dependency
    error_message = "lock_dependency should change with the body, so the policy's lock is removed around an update."
  }
}

run "overrides" {
  command = apply

  variables {
    resource_types      = { network_firewall_policies_rule_collection_groups = "Microsoft.Network/firewallPolicies/ruleCollectionGroups@2025-05-01" }
    ignore_body_changes = { network_firewall_policies_rule_collection_groups = ["properties.priority"] }
    retry               = { error_message_regex = ["Conflict"] }
    timeouts            = { create = "10m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/firewallPolicies/ruleCollectionGroups@2025-05-01"
    error_message = "resource_types should override the API version."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["Conflict"]) && azapi_resource.this.retry.interval_seconds == 30 && azapi_resource.this.timeouts.create == "10m"
    error_message = "One retry field should be overridable while the others keep their defaults, and timeouts should reach the group."
  }
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.parent_id]
}

run "invalid_priority" {
  command = plan

  variables {
    priority = 50
  }

  expect_failures = [var.priority]
}

run "invalid_application_action" {
  command = plan

  variables {
    application_rule_collections = {
      app = { priority = 300, action = "Dnat", rules = {} }
    }
  }

  expect_failures = [var.application_rule_collections]
}

run "invalid_network_protocol" {
  command = plan

  variables {
    network_rule_collections = {
      net = {
        priority = 400
        action   = "Allow"
        rules = {
          bad = { protocols = ["HTTP"], destination_addresses = ["*"], destination_ports = ["80"] }
        }
      }
    }
  }

  expect_failures = [var.network_rule_collections]
}

run "nat_with_both_translations" {
  command = plan

  variables {
    nat_rule_collections = {
      dnat = {
        priority = 100
        rules = {
          bad = {
            protocols           = ["TCP"]
            destination_address = "203.0.113.10"
            destination_ports   = ["443"]
            translated_address  = "10.0.0.4"
            translated_fqdn     = "app.example.com"
            translated_port     = 443
          }
        }
      }
    }
  }

  expect_failures = [var.nat_rule_collections]
}

run "duplicate_collection_names" {
  command = plan

  variables {
    application_rule_collections = {
      shared = { priority = 300, action = "Allow", rules = {} }
    }
    network_rule_collections = {
      shared = { priority = 400, action = "Allow", rules = {} }
    }
  }

  expect_failures = [var.nat_rule_collections]
}
