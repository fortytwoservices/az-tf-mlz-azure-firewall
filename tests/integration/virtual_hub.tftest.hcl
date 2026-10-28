# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# A Standard firewall in a Virtual WAN hub, billed by the hour with the hub while they exist: the run
# destroys them at the end. Proves what mocks cannot: the default API versions take a hub firewall
# (AZFW_Hub) with Azure-managed public IPs and the hub's routing intent; the public IP count and the
# routing policies change in place.

run "setup" {
  module {
    source = "./tests/integration/virtual_hub_setup"
  }
}

run "create_in_virtual_hub" {
  variables {
    name            = "afw-mlz-it-${run.setup.suffix}"
    parent_id       = run.setup.resource_group_id
    location        = run.setup.location
    virtual_network = null
    virtual_hub = {
      virtual_hub_id = run.setup.virtual_hub_id
      routing_intent = {}
    }
    firewall_policy = { name = "afwp-mlz-it-${run.setup.suffix}" }
    rule_collection_groups = {
      platform = {
        priority = 200
        network_rule_collections = {
          spokes = {
            priority = 300
            action   = "Allow"
            rules = {
              dns = { protocols = ["UDP"], source_addresses = ["10.0.0.0/8"], destination_addresses = ["168.63.129.16"], destination_ports = ["53"] }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = cidrsubnet("${output.private_ip_address}/23", 0, 0) == "10.100.0.0/23"
    error_message = "The firewall's private IP address should be in the hub's address space, got ${output.private_ip_address}."
  }
  assert {
    condition     = length(output.hub_public_ip_addresses) == 1 && output.routing_intent_resource_id != null
    error_message = "One Azure-managed public IP and the routing intent should exist, got ${jsonencode(output.hub_public_ip_addresses)}."
  }
}

run "more_public_ips_and_internet_traffic_only" {
  variables {
    name            = "afw-mlz-it-${run.setup.suffix}"
    parent_id       = run.setup.resource_group_id
    location        = run.setup.location
    virtual_network = null
    virtual_hub = {
      virtual_hub_id  = run.setup.virtual_hub_id
      public_ip_count = 2
      routing_intent  = { private_traffic = false }
    }
    firewall_policy = { name = "afwp-mlz-it-${run.setup.suffix}" }
    rule_collection_groups = {
      platform = {
        priority = 200
        network_rule_collections = {
          spokes = {
            priority = 300
            action   = "Allow"
            rules = {
              dns = { protocols = ["UDP"], source_addresses = ["10.0.0.0/8"], destination_addresses = ["168.63.129.16"], destination_ports = ["53"] }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(output.hub_public_ip_addresses) == 2 && output.private_ip_address == run.create_in_virtual_hub.private_ip_address
    error_message = "The firewall should have two public IPs and keep its private IP address, got ${jsonencode(output.hub_public_ip_addresses)}."
  }
}
