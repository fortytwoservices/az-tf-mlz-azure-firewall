mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ipGroups/ipg-test"
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
  location     = "norwayeast"
  name         = "ipg-test"
  parent_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  ip_addresses = ["10.2.0.0-10.2.0.31", "10.1.0.0/24", "10.0.0.4"]
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/ipGroups@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The IP group should use the default resource type, name, parent_id and location."
  }
  assert {
    condition     = azapi_resource.this.body.properties.ipAddresses == tolist(["10.0.0.4", "10.1.0.0/24", "10.2.0.0-10.2.0.31"])
    error_message = "The addresses should be sent sorted."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "retry, timeouts and tags should be unset by default."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) == 0
    error_message = "No lock or role assignment should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name
    error_message = "resource_id and name should come from the IP group."
  }
}

run "interfaces_and_overrides" {
  command = apply

  # The interface keys of resource_types and ignore_body_changes, retry and timeouts go to
  # az-tf-mlz-interfaces, whose tests check them; ignore_body_changes is write-only.
  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = "55555555-5555-5555-5555-555555555555" }
    }
    resource_types      = { network_ip_groups = "Microsoft.Network/ipGroups@2025-05-01" }
    ignore_body_changes = { network_ip_groups = ["properties.ipAddresses"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "15m" }
    tags                = { environment = "test" }
  }

  assert {
    condition     = module.interfaces.lock_resource_id != null && keys(module.interfaces.role_assignment_resource_ids) == ["reader"]
    error_message = "The lock and role assignments should be created through az-tf-mlz-interfaces."
  }
  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/ipGroups@2025-05-01" && azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "resource_types and tags should reach the IP group."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "15m"
    error_message = "retry and timeouts should reach the IP group."
  }
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "invalid_lock_kind" {
  command = plan

  variables {
    lock = { kind = "Delete" }
  }

  expect_failures = [var.lock]
}
