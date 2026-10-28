mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test/routingIntent/RoutingIntent"
    }
  }
}

variables {
  name      = "RoutingIntent"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualHubs/vhub-test"
  routing_policies = {
    InternetTraffic      = { destinations = ["Internet"], next_hop_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/azureFirewalls/afw-test" }
    PrivateTrafficPolicy = { destinations = ["PrivateTraffic"], next_hop_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/azureFirewalls/afw-test" }
  }
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/virtualHubs/routingIntent@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id
    error_message = "The routing intent should use the default resource type, name and parent_id."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body.properties.routingPolicies) == jsonencode([
      { name = "InternetTraffic", destinations = ["Internet"], nextHop = var.routing_policies.InternetTraffic.next_hop_id },
      { name = "PrivateTrafficPolicy", destinations = ["PrivateTraffic"], nextHop = var.routing_policies.PrivateTrafficPolicy.next_hop_id },
    ])
    error_message = "Each routing policy should map to the body, by name."
  }
  assert {
    condition     = azapi_resource.this.locks == tolist([var.parent_id]) && azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"])
    error_message = "Writes should be serialised on the hub, with AnotherOperationInProgress retried."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name
    error_message = "resource_id and name should come from the routing intent."
  }
}

run "overrides" {
  command = apply

  variables {
    resource_types      = { network_virtual_hubs_routing_intent = "Microsoft.Network/virtualHubs/routingIntent@2025-05-01" }
    ignore_body_changes = { network_virtual_hubs_routing_intent = ["properties.routingPolicies"] }
    retry               = { error_message_regex = ["Conflict"] }
    timeouts            = { create = "45m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/virtualHubs/routingIntent@2025-05-01" && azapi_resource.this.retry.error_message_regex == tolist(["Conflict"]) && azapi_resource.this.timeouts.create == "45m"
    error_message = "resource_types, retry and timeouts should reach the routing intent."
  }
}

run "unknown_destination" {
  command = plan

  variables {
    routing_policies = {
      Everything = { destinations = ["Internet", "Branches"], next_hop_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/azureFirewalls/afw-test" }
    }
  }

  expect_failures = [var.routing_policies]
}

run "destination_in_two_policies" {
  command = plan

  variables {
    routing_policies = {
      One = { destinations = ["Internet"], next_hop_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/azureFirewalls/afw-test" }
      Two = { destinations = ["Internet"], next_hop_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/azureFirewalls/afw-test" }
    }
  }

  expect_failures = [var.routing_policies]
}

run "no_policies" {
  command = plan

  variables {
    routing_policies = {}
  }

  expect_failures = [var.routing_policies]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.parent_id]
}
