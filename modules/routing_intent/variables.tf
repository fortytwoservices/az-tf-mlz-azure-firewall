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

variable "replace_triggers" {
  type        = any
  default     = null
  description = "(Optional) Values whose change replaces the routing intent, for example the next hop's own replacement triggers: a replaced firewall keeps its resource ID, so without them the routing intent would still point at the firewall being deleted. The root module passes the firewall's."
}

variable "routing_policies" {
  type = map(object({
    destinations = list(string)
    next_hop_id  = string
  }))
  nullable    = false
  description = <<DESCRIPTION
Routing policies, by policy name, for example `{ InternetTraffic = { destinations = ["Internet"], next_hop_id = <firewall ID> } }`. A hub has at most one Internet and one private traffic policy (Microsoft Learn); Azure prescribes no names (Learn's examples use `PublicTraffic` and `PrivateTraffic`).

- `destinations` - One destination: `["Internet"]` or `["PrivateTraffic"]`, each in one policy only.
- `next_hop_id` - Resource ID of the next hop, usually the hub's Azure Firewall.
DESCRIPTION

  validation {
    condition     = length(var.routing_policies) > 0 && alltrue([for policy in values(var.routing_policies) : length(policy.destinations) == 1 && alltrue([for destination in policy.destinations : contains(["Internet", "PrivateTraffic"], destination)])])
    error_message = "`routing_policies` needs at least one policy, each with one destination: `Internet` or `PrivateTraffic`."
  }
  validation {
    condition     = length(flatten([for policy in values(var.routing_policies) : policy.destinations])) == length(distinct(flatten([for policy in values(var.routing_policies) : policy.destinations])))
    error_message = "Each destination may appear in one routing policy only."
  }
}
