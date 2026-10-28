# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# A Basic firewall, the cheapest tier, billed by the hour while it exists: the run destroys it at the end.
# Proves what mocks cannot: the default API versions and bodies are accepted for a Basic firewall with a
# management IP configuration, a created Basic policy, IP groups and rules; rules change, and a rule
# collection group and an IP group it used are deleted, under the policy's lock; a further public IP is
# added to the locked firewall; the policy and an IP group in use are renamed (created before destroyed).

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name      = "afw-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku_tier  = "Basic"
    virtual_network = {
      subnet_id = run.setup.firewall_subnet_id
      public_ip = { name = "pip-mlz-it-${run.setup.suffix}" }
      management = {
        subnet_id = run.setup.management_subnet_id
        public_ip = { name = "pip-mlz-it-${run.setup.suffix}-mgmt" }
      }
    }
    firewall_policy = {
      name = "afwp-mlz-it-${run.setup.suffix}"
      lock = { kind = "CanNotDelete" }
    }
    ip_groups = {
      spokes = { name = "ipg-mlz-it-${run.setup.suffix}-spokes", ip_addresses = ["10.1.0.0/16"] }
      legacy = { name = "ipg-mlz-it-${run.setup.suffix}-legacy", ip_addresses = ["10.9.0.0/16"] }
    }
    rule_collection_groups = {
      platform = {
        priority = 200
        network_rule_collections = {
          dns = {
            priority = 300
            action   = "Allow"
            rules = {
              spokes = { protocols = ["UDP"], source_ip_groups = ["spokes"], destination_addresses = ["168.63.129.16"], destination_ports = ["53"] }
            }
          }
        }
        application_rule_collections = {
          updates = {
            priority = 400
            action   = "Allow"
            rules = {
              windows-update = { source_ip_groups = ["spokes"], protocols = [{ type = "Https", port = 443 }], destination_fqdn_tags = ["WindowsUpdate"] }
            }
          }
        }
      }
      legacy = {
        priority = 300
        network_rule_collections = {
          legacy = {
            priority = 500
            action   = "Deny"
            rules = {
              all = { protocols = ["Any"], source_ip_groups = ["legacy"], destination_addresses = ["*"], destination_ports = ["*"] }
            }
          }
        }
      }
    }
    lock = { kind = "CanNotDelete" }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  assert {
    condition     = cidrsubnet("${output.private_ip_address}/26", 0, 0) == "10.0.0.0/26"
    error_message = "The firewall's private IP address should be in AzureFirewallSubnet, got ${output.private_ip_address}."
  }
  assert {
    condition     = length(output.public_ip_addresses) == 2 && alltrue([for address in values(output.public_ip_addresses) : can(cidrhost("${address}/32", 0))])
    error_message = "The data-path and management public IP addresses should be created."
  }
}

run "change_rules_and_delete_a_group_under_the_policy_lock" {
  # The legacy rule collection group and the IP group only it used are deleted, and a rule changes, while
  # the policy's lock stays configured: the lock is removed and created again around the change.
  variables {
    name      = "afw-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku_tier  = "Basic"
    virtual_network = {
      subnet_id = run.setup.firewall_subnet_id
      public_ip = { name = "pip-mlz-it-${run.setup.suffix}" }
      management = {
        subnet_id = run.setup.management_subnet_id
        public_ip = { name = "pip-mlz-it-${run.setup.suffix}-mgmt" }
      }
    }
    firewall_policy = {
      name = "afwp-mlz-it-${run.setup.suffix}"
      lock = { kind = "CanNotDelete" }
    }
    ip_groups = {
      spokes = { name = "ipg-mlz-it-${run.setup.suffix}-spokes", ip_addresses = ["10.1.0.0/16", "10.2.0.0/16"] }
    }
    rule_collection_groups = {
      platform = {
        priority = 200
        network_rule_collections = {
          dns = {
            priority = 300
            action   = "Allow"
            rules = {
              spokes = { description = "DNS from the spokes", protocols = ["UDP", "TCP"], source_ip_groups = ["spokes"], destination_addresses = ["168.63.129.16"], destination_ports = ["53"] }
            }
          }
        }
        application_rule_collections = {
          updates = {
            priority = 400
            action   = "Allow"
            rules = {
              windows-update = { source_ip_groups = ["spokes"], protocols = [{ type = "Https", port = 443 }], destination_fqdn_tags = ["WindowsUpdate"] }
            }
          }
        }
      }
    }
    lock = { kind = "CanNotDelete" }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  assert {
    condition     = keys(output.rule_collection_group_resource_ids) == ["platform"] && keys(output.ip_group_resource_ids) == ["spokes"]
    error_message = "The legacy rule collection group and IP group should be gone."
  }
}

run "add_a_public_ip_to_the_locked_firewall" {
  variables {
    name      = "afw-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku_tier  = "Basic"
    virtual_network = {
      subnet_id = run.setup.firewall_subnet_id
      public_ip = { name = "pip-mlz-it-${run.setup.suffix}" }
      additional_public_ips = {
        egress-2 = { name = "pip-mlz-it-${run.setup.suffix}-2" }
      }
      management = {
        subnet_id = run.setup.management_subnet_id
        public_ip = { name = "pip-mlz-it-${run.setup.suffix}-mgmt" }
      }
    }
    firewall_policy = {
      name = "afwp-mlz-it-${run.setup.suffix}"
      lock = { kind = "CanNotDelete" }
    }
    ip_groups = {
      spokes = { name = "ipg-mlz-it-${run.setup.suffix}-spokes", ip_addresses = ["10.1.0.0/16", "10.2.0.0/16"] }
    }
    rule_collection_groups = {
      platform = {
        priority = 200
        network_rule_collections = {
          dns = {
            priority = 300
            action   = "Allow"
            rules = {
              spokes = { description = "DNS from the spokes", protocols = ["UDP", "TCP"], source_ip_groups = ["spokes"], destination_addresses = ["168.63.129.16"], destination_ports = ["53"] }
            }
          }
        }
        application_rule_collections = {
          updates = {
            priority = 400
            action   = "Allow"
            rules = {
              windows-update = { source_ip_groups = ["spokes"], protocols = [{ type = "Https", port = 443 }], destination_fqdn_tags = ["WindowsUpdate"] }
            }
          }
        }
      }
    }
    lock = { kind = "CanNotDelete" }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  assert {
    condition     = length(output.public_ip_address_ids) == 3 && output.private_ip_address == run.create.private_ip_address
    error_message = "The firewall should have a third public IP and keep its private IP address."
  }
}

run "rename_the_policy_and_an_ip_group_in_use" {
  # Azure deletes neither a policy a firewall uses nor an IP group a rule uses, so both are created under
  # their new names first; the firewall and the rules move to them; the old ones go last. The policy's
  # lock moves with it.
  variables {
    name      = "afw-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku_tier  = "Basic"
    virtual_network = {
      subnet_id = run.setup.firewall_subnet_id
      public_ip = { name = "pip-mlz-it-${run.setup.suffix}" }
      additional_public_ips = {
        egress-2 = { name = "pip-mlz-it-${run.setup.suffix}-2" }
      }
      management = {
        subnet_id = run.setup.management_subnet_id
        public_ip = { name = "pip-mlz-it-${run.setup.suffix}-mgmt" }
      }
    }
    firewall_policy = {
      name = "afwp-mlz-it-${run.setup.suffix}-renamed"
      lock = { kind = "CanNotDelete" }
    }
    ip_groups = {
      spokes = { name = "ipg-mlz-it-${run.setup.suffix}-spokes-renamed", ip_addresses = ["10.1.0.0/16", "10.2.0.0/16"] }
    }
    rule_collection_groups = {
      platform = {
        priority = 200
        network_rule_collections = {
          dns = {
            priority = 300
            action   = "Allow"
            rules = {
              spokes = { description = "DNS from the spokes", protocols = ["UDP", "TCP"], source_ip_groups = ["spokes"], destination_addresses = ["168.63.129.16"], destination_ports = ["53"] }
            }
          }
        }
        application_rule_collections = {
          updates = {
            priority = 400
            action   = "Allow"
            rules = {
              windows-update = { source_ip_groups = ["spokes"], protocols = [{ type = "Https", port = 443 }], destination_fqdn_tags = ["WindowsUpdate"] }
            }
          }
        }
      }
    }
    lock = { kind = "CanNotDelete" }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  assert {
    condition     = endswith(output.firewall_policy_resource_id, "-renamed") && endswith(output.ip_group_resource_ids.spokes, "-renamed") && output.private_ip_address == run.create.private_ip_address
    error_message = "The firewall should use the renamed policy, and the rules the renamed IP group."
  }
}
