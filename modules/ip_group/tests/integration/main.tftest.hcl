# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/ip_group
# Proves what mocks cannot: the default API version and body are accepted, Azure returns the addresses as
# sent (sorted), and a change of addresses reaches Azure under the lock.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name         = "ipg-mlz-it-${run.setup.suffix}"
    parent_id    = run.setup.resource_group_id
    location     = run.setup.location
    ip_addresses = ["10.1.0.0/24", "10.0.0.4"]
    lock         = { kind = "CanNotDelete" }
  }
}

run "update_addresses" {
  variables {
    name         = "ipg-mlz-it-${run.setup.suffix}"
    parent_id    = run.setup.resource_group_id
    location     = run.setup.location
    ip_addresses = ["10.1.0.0/24", "10.2.0.0-10.2.0.31"]
    lock         = { kind = "CanNotDelete" }
    tags         = { updated = "true" }
  }

}

run "addresses_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    ip_group_id = run.update_addresses.resource_id
  }

  assert {
    condition     = tolist(output.ip_addresses) == tolist(["10.1.0.0/24", "10.2.0.0-10.2.0.31"])
    error_message = "Azure should return the new addresses as sent, got ${jsonencode(output.ip_addresses)}."
  }
}
