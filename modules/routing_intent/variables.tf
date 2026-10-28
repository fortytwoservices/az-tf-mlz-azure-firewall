variable "name" {
  type        = string
  description = "Name of the routing intent. A hub has one."
  nullable    = false
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the Virtual WAN hub."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/virtualHubs", var.parent_id))
    error_message = "`parent_id` must be a virtual hub resource ID."
  }
}

variable "routing_policies" {
  type = map(object({
    destinations = list(string)
    next_hop_id  = string
  }))
  nullable    = false
  description = <<DESCRIPTION
Routing policies, by policy name, for example `{ InternetTraffic = { destinations = ["Internet"], next_hop_id = <firewall ID> } }`:

- `destinations` - `Internet` and/or `PrivateTraffic`; each destination in one policy only.
- `next_hop_id` - Resource ID of the next hop, usually the hub's Azure Firewall.
DESCRIPTION

  validation {
    condition     = length(var.routing_policies) > 0 && alltrue([for policy in values(var.routing_policies) : length(policy.destinations) > 0 && alltrue([for destination in policy.destinations : contains(["Internet", "PrivateTraffic"], destination)])])
    error_message = "`routing_policies` needs at least one policy, each with `Internet` and/or `PrivateTraffic` destinations."
  }
  validation {
    condition     = length(flatten([for policy in values(var.routing_policies) : policy.destinations])) == length(distinct(flatten([for policy in values(var.routing_policies) : policy.destinations])))
    error_message = "Each destination may appear in one routing policy only."
  }
}
