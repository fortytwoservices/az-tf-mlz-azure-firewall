mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/azureFirewalls/afw-test"
      output = {
        properties = {
          ipAddress        = "203.0.113.10"
          ipConfigurations = [{ properties = { privateIPAddress = "10.0.0.4" } }]
          hubIPAddresses = {
            privateIPAddress = "10.100.0.132"
            publicIPs        = { addresses = [{ address = "203.0.113.20" }], count = 1 }
          }
        }
      }
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
  name      = "afw-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  virtual_network = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
    public_ip = { name = "pip-afw-test" }
  }
  firewall_policy = { name = "afwp-test" }
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/azureFirewalls@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The firewall should use the default resource type, name, parent_id and location."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body) == jsonencode({
      properties = {
        sku            = { name = "AZFW_VNet", tier = "Standard" }
        firewallPolicy = { id = module.firewall_policy[0].resource_id }
        ipConfigurations = [{
          name = "ipconfig"
          properties = {
            subnet          = { id = var.virtual_network.subnet_id }
            publicIPAddress = { id = module.public_ip["ipconfig"].resource_id }
          }
        }]
        managementIpConfiguration = null
        autoscaleConfiguration    = null
      }
    })
    error_message = "A Standard VNet firewall should get the policy and one IP configuration with the subnet and the created public IP, and no zones."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.zones == null && azapi_resource.this.replace_triggers_external_values.management == false && azapi_resource.this.replace_triggers_external_values.basic == false && azapi_resource.this.replace_triggers_external_values.subnet_id == lower(var.virtual_network.subnet_id) && azapi_resource.this.replace_triggers_refs == tolist(["properties.sku.name"])
    error_message = "Zones, the management NIC, the virtual network, crossing the Basic tier and the SKU name should replace the firewall."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "The default retry should cover AnotherOperationInProgress, with no timeouts or tags."
  }
  assert {
    condition     = keys(module.public_ip) == ["ipconfig"] && length(module.firewall_policy) == 1 && length(module.rule_collection_group) + length(module.ip_group) == 0
    error_message = "One public IP and the policy should be created, and no rules or IP groups."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) + length(module.interfaces.diagnostic_setting_resource_ids) == 0
    error_message = "No lock, role assignment or diagnostic setting should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && output.private_ip_address == "10.0.0.4" && output.firewall_policy_resource_id == module.firewall_policy[0].resource_id
    error_message = "resource_id, name, private_ip_address and firewall_policy_resource_id should come from the firewall and its policy."
  }
  assert {
    condition     = jsonencode(output.public_ip_address_ids) == jsonencode({ ipconfig = module.public_ip["ipconfig"].resource_id }) && jsonencode(output.public_ip_addresses) == jsonencode({ ipconfig = "203.0.113.10" }) && length(output.hub_public_ip_addresses) == 0
    error_message = "The public IP outputs should be keyed by IP configuration name."
  }
}

run "basic_with_management_and_more_public_ips" {
  command = apply

  variables {
    sku_tier = "Basic"
    zones    = ["3", "1", "2"]
    virtual_network = {
      subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
      public_ip_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"
      additional_public_ips = {
        egress-2 = { name = "pip-afw-test-2", public_ip_prefix_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-test" }
      }
      additional_public_ip_resource_ids = {
        egress-3 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing-3"
      }
      management = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallManagementSubnet"
        public_ip = { name = "pip-afw-test-mgmt" }
      }
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.sku.tier == "Basic" && azapi_resource.this.replace_triggers_external_values.basic && module.firewall_policy[0].name == "afwp-test"
    error_message = "The tier should reach the firewall, and Basic should be a replacement trigger."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body.properties.ipConfigurations) == jsonencode([
      {
        name = "ipconfig"
        properties = {
          subnet          = { id = var.virtual_network.subnet_id }
          publicIPAddress = { id = var.virtual_network.public_ip_resource_id }
        }
      },
      {
        name       = "egress-2"
        properties = { publicIPAddress = { id = module.public_ip["egress-2"].resource_id } }
      },
      {
        name       = "egress-3"
        properties = { publicIPAddress = { id = var.virtual_network.additional_public_ip_resource_ids["egress-3"] } }
      },
    ])
    error_message = "The first IP configuration should hold the subnet and the given public IP, and each further public IP, created or given, its own configuration without a subnet."
  }
  assert {
    condition     = azapi_resource.this.body.properties.managementIpConfiguration.name == "management" && azapi_resource.this.body.properties.managementIpConfiguration.properties.subnet.id == var.virtual_network.management.subnet_id && azapi_resource.this.body.properties.managementIpConfiguration.properties.publicIPAddress.id == module.public_ip["management"].resource_id
    error_message = "The management IP configuration should hold its subnet and its own created public IP."
  }
  assert {
    condition     = azapi_resource.this.body.zones == tolist(["1", "2", "3"]) && azapi_resource.this.replace_triggers_external_values.zones == tolist(["1", "2", "3"]) && azapi_resource.this.replace_triggers_external_values.management
    error_message = "Zones should be sent sorted and replace the firewall when they change, and the management NIC's presence should be a replacement trigger."
  }
  assert {
    condition     = toset(keys(module.public_ip)) == toset(["egress-2", "management"])
    error_message = "Only the public IPs with a name should be created."
  }
  assert {
    condition     = jsonencode(terraform_data.public_ip_destroy_order.input) == jsonencode({ for name, public_ip in module.public_ip : name => public_ip.resource_id })
    error_message = "The destroy-order resource should depend on every created public IP, so that they inherit its create_before_destroy."
  }
  assert {
    condition     = output.public_ip_address_ids.ipconfig == var.virtual_network.public_ip_resource_id && length(output.public_ip_address_ids) == 4 && !contains(keys(output.public_ip_addresses), "ipconfig")
    error_message = "public_ip_address_ids should hold every public IP, and public_ip_addresses only the created ones."
  }
}

run "existing_policy_with_rules_and_ip_groups" {
  command = apply

  variables {
    firewall_policy    = null
    firewall_policy_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/firewallPolicies/afwp-existing"
    ip_groups = {
      spokes = { name = "ipg-spokes", ip_addresses = ["10.1.0.0/16"] }
    }
    rule_collection_groups = {
      platform = {
        priority = 200
        network_rule_collections = {
          spokes-out = {
            priority = 300
            action   = "Allow"
            rules = {
              dns = {
                protocols             = ["UDP"]
                source_ip_groups      = ["spokes"]
                destination_ip_groups = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ipGroups/ipg-dns"]
                destination_ports     = ["53"]
              }
            }
          }
        }
        application_rule_collections = {
          web = {
            priority = 400
            action   = "Allow"
            rules = {
              updates = { source_ip_groups = ["spokes"], protocols = [{ type = "Https", port = 443 }], destination_fqdn_tags = ["WindowsUpdate"] }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(module.firewall_policy) == 0 && azapi_resource.this.body.properties.firewallPolicy.id == var.firewall_policy_id && output.firewall_policy_resource_id == var.firewall_policy_id
    error_message = "An existing policy should be used as given, without creating one."
  }
  assert {
    condition     = jsonencode(local.rule_collection_groups.platform.network_rule_collections["spokes-out"].rules.dns.source_ip_groups) == jsonencode([module.ip_group["spokes"].resource_id]) && jsonencode(local.rule_collection_groups.platform.network_rule_collections["spokes-out"].rules.dns.destination_ip_groups) == jsonencode(["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ipGroups/ipg-dns"])
    error_message = "An IP group key should become the created group's ID, and an ID should be passed on."
  }
  assert {
    condition     = jsonencode(local.rule_collection_groups.platform.application_rule_collections.web.rules.updates.source_ip_groups) == jsonencode([module.ip_group["spokes"].resource_id])
    error_message = "IP group keys should also resolve in application rules."
  }
  assert {
    condition     = keys(output.rule_collection_group_resource_ids) == ["platform"] && keys(output.ip_group_resource_ids) == ["spokes"]
    error_message = "The rule collection groups and IP groups should be output by key."
  }
}

run "forced_tunnelling_without_a_data_path_public_ip" {
  command = apply

  variables {
    virtual_network = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
      management = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallManagementSubnet"
        public_ip = { name = "pip-afw-test-mgmt" }
      }
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.ipConfigurations[0].properties.subnet.id == var.virtual_network.subnet_id && azapi_resource.this.body.properties.ipConfigurations[0].properties.publicIPAddress == null && length(azapi_resource.this.body.properties.ipConfigurations) == 1
    error_message = "The subnet configuration should hold the subnet without a public IP."
  }
  assert {
    condition     = azapi_resource.this.body.properties.managementIpConfiguration.properties.publicIPAddress.id == module.public_ip["management"].resource_id
    error_message = "The management configuration should keep its own public IP."
  }
  assert {
    condition     = jsonencode([keys(module.public_ip), keys(output.public_ip_address_ids), keys(output.public_ip_addresses)]) == jsonencode([["management"], ["management"], ["management"]])
    error_message = "Only the management public IP should be created and output."
  }
}

run "virtual_hub_with_routing_intent" {
  command = apply

  variables {
    virtual_network = null
    virtual_hub = {
      virtual_hub_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
      public_ip_count = 2
      routing_intent  = {}
    }
  }

  assert {
    condition = jsonencode(azapi_resource.this.body.properties) == jsonencode({
      autoscaleConfiguration = null
      firewallPolicy         = { id = module.firewall_policy[0].resource_id }
      hubIPAddresses         = { publicIPs = { count = 2 } }
      sku                    = { name = "AZFW_Hub", tier = "Standard" }
      virtualHub             = { id = var.virtual_hub.virtual_hub_id }
    })
    error_message = "A Virtual WAN hub firewall should get the hub, a count of Azure-managed public IPs and the policy, and no IP configurations."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.subnet_id == lower(var.virtual_hub.virtual_hub_id) && azapi_resource.this.replace_triggers_external_values.management == false && azapi_resource.this.replace_triggers_refs == tolist(["properties.sku.name"])
    error_message = "Moving to another hub, and switching between hub kinds (the SKU name), should replace the firewall."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.replace_triggers_external_values) == jsonencode(local.firewall_replace_triggers)
    error_message = "The firewall's replacement triggers should be the local the routing intent also receives."
  }
  assert {
    condition     = length(module.public_ip) == 0 && length(module.routing_intent) == 1 && output.routing_intent_resource_id == module.routing_intent[0].resource_id
    error_message = "No public IP resources and one routing intent should be created."
  }
  assert {
    condition     = output.private_ip_address == "10.100.0.132" && jsonencode(output.hub_public_ip_addresses) == jsonencode(["203.0.113.20"]) && length(output.public_ip_address_ids) == 0 && length(output.public_ip_addresses) == 0
    error_message = "The private and public IP addresses should come from the hub's IP addresses."
  }
}

run "virtual_hub_with_internet_traffic_only" {
  command = apply

  variables {
    virtual_network = null
    virtual_hub = {
      virtual_hub_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
      routing_intent = { private_traffic = false }
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.hubIPAddresses.publicIPs.count == 1 && length(module.routing_intent) == 1
    error_message = "One public IP by default, and a routing intent for Internet traffic only."
  }
}

run "virtual_hub_without_routing_intent" {
  command = apply

  variables {
    virtual_network = null
    virtual_hub = {
      virtual_hub_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
    }
  }

  assert {
    condition     = length(module.routing_intent) == 0 && output.routing_intent_resource_id == null
    error_message = "No routing intent should be created when another state manages it."
  }
}

run "both_hub_kinds" {
  command = plan

  variables {
    virtual_hub = {
      virtual_hub_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
    }
  }

  expect_failures = [var.virtual_hub]
}

run "no_hub_kind" {
  command = plan

  variables {
    virtual_network = null
  }

  expect_failures = [var.virtual_hub]
}

run "routing_intent_without_policies" {
  command = plan

  variables {
    virtual_network = null
    virtual_hub = {
      virtual_hub_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
      routing_intent = { internet_traffic = false, private_traffic = false }
    }
  }

  expect_failures = [var.virtual_hub]
}

run "invalid_public_ip_count" {
  command = plan

  variables {
    virtual_network = null
    virtual_hub = {
      virtual_hub_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
      public_ip_count = 0
    }
  }

  expect_failures = [var.virtual_hub]
}

run "more_than_80_hub_public_ips" {
  command = plan

  variables {
    virtual_network = null
    virtual_hub = {
      virtual_hub_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
      public_ip_count = 81
    }
  }

  expect_failures = [var.virtual_hub]
}

run "basic_in_virtual_hub" {
  command = plan

  variables {
    sku_tier        = "Basic"
    virtual_network = null
    virtual_hub = {
      virtual_hub_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
    }
  }

  expect_failures = [var.virtual_hub]
}

run "interfaces_and_overrides" {
  command = apply

  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = "55555555-5555-5555-5555-555555555555" }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
        logs                  = [{ category_group = "allLogs" }]
      }
    }
    autoscale = {
      min_capacity = 2
      max_capacity = 4
    }
    resource_types      = { network_azure_firewalls = "Microsoft.Network/azureFirewalls@2025-05-01" }
    ignore_body_changes = { network_azure_firewalls = ["properties.autoscaleConfiguration"] }
    retry               = { error_message_regex = ["Conflict"] }
    timeouts            = { create = "60m" }
    tags                = { environment = "test" }
  }

  # The interface keys of resource_types and ignore_body_changes, retry and timeouts go to the submodules
  # and az-tf-mlz-interfaces, whose tests check them; ignore_body_changes is write-only.
  assert {
    condition     = module.interfaces.lock_resource_id != null && keys(module.interfaces.role_assignment_resource_ids) == ["reader"] && keys(module.interfaces.diagnostic_setting_resource_ids) == ["workspace"]
    error_message = "The lock, role assignments and diagnostic settings should be created through az-tf-mlz-interfaces."
  }
  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/azureFirewalls@2025-05-01" && azapi_resource.this.tags == tomap({ environment = "test" }) && jsonencode(azapi_resource.this.body.properties.autoscaleConfiguration) == jsonencode({ minCapacity = 2, maxCapacity = 4 })
    error_message = "resource_types, tags and autoscale should reach the firewall."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["Conflict"]) && azapi_resource.this.retry.interval_seconds == 30 && azapi_resource.this.timeouts.create == "60m"
    error_message = "One retry field should be overridable while the others keep their defaults, and timeouts should reach the firewall."
  }
}

run "basic_without_management" {
  command = plan

  variables {
    sku_tier = "Basic"
  }

  expect_failures = [var.virtual_network]
}

run "both_policy_inputs" {
  command = plan

  variables {
    firewall_policy_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/firewallPolicies/afwp-existing"
  }

  expect_failures = [var.firewall_policy_id]
}

run "no_policy" {
  command = plan

  variables {
    firewall_policy = null
  }

  expect_failures = [var.firewall_policy_id]
}

run "created_and_existing_public_ip" {
  command = plan

  variables {
    virtual_network = {
      subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
      public_ip             = { name = "pip-afw-test" }
      public_ip_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"
    }
  }

  expect_failures = [var.virtual_network]
}

run "wrong_subnet" {
  command = plan

  variables {
    virtual_network = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/snet-workload"
      public_ip = { name = "pip-afw-test" }
    }
  }

  expect_failures = [var.virtual_network]
}

run "no_public_ip_without_management" {
  command = plan

  variables {
    virtual_network = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
    }
  }

  expect_failures = [var.virtual_network]
}

run "duplicate_ip_configuration_names" {
  command = plan

  variables {
    virtual_network = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
      public_ip = { name = "pip-afw-test" }
      additional_public_ips = {
        ipconfig = { name = "pip-afw-test-2" }
      }
    }
  }

  expect_failures = [var.virtual_network]
}

run "management_with_two_public_ips" {
  command = plan

  variables {
    virtual_network = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
      public_ip = { name = "pip-afw-test" }
      management = {
        subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallManagementSubnet"
        public_ip             = { name = "pip-afw-test-mgmt" }
        public_ip_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"
      }
    }
  }

  expect_failures = [var.virtual_network]
}

run "duplicate_additional_ip_configuration_keys" {
  command = plan

  variables {
    virtual_network = {
      subnet_id                         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
      public_ip                         = { name = "pip-afw-test" }
      additional_public_ips             = { egress-2 = { name = "pip-afw-test-2" } }
      additional_public_ip_resource_ids = { egress-2 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing" }
    }
  }

  expect_failures = [var.virtual_network]
}

run "invalid_zone" {
  command = plan

  variables {
    zones = ["4"]
  }

  expect_failures = [var.zones]
}

run "invalid_name" {
  command = plan

  variables {
    name = "afw-${join("", [for i in range(60) : "x"])}"
  }

  expect_failures = [var.name]
}

run "invalid_autoscale" {
  command = plan

  variables {
    autoscale = { min_capacity = 1 }
  }

  expect_failures = [var.autoscale]
}

run "autoscale_capacities_one_apart" {
  command = plan

  variables {
    autoscale = { min_capacity = 5, max_capacity = 6 }
  }

  expect_failures = [var.autoscale]
}

run "autoscale_on_basic" {
  command = plan

  variables {
    sku_tier  = "Basic"
    autoscale = { min_capacity = 2, max_capacity = 4 }
    virtual_network = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallSubnet"
      public_ip = { name = "pip-afw-test" }
      management = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureFirewallManagementSubnet"
        public_ip = { name = "pip-afw-test-mgmt" }
      }
    }
  }

  expect_failures = [var.autoscale]
}
