variable "name" {
  type        = string
  description = "Name of the rule collection group. Changing it replaces the group."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, underscores, periods and hyphens, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the firewall policy that holds the group."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/firewallPolicies", var.parent_id))
    error_message = "`parent_id` must be a firewall policy resource ID."
  }
}

variable "priority" {
  type        = number
  description = "Priority of the group within the policy, 100 to 65000; lower is processed first."
  nullable    = false

  validation {
    condition     = var.priority >= 100 && var.priority <= 65000 && floor(var.priority) == var.priority
    error_message = "`priority` must be a whole number from 100 to 65000."
  }
}

variable "application_rule_collections" {
  type = map(object({
    priority = number
    action   = string
    rules = map(object({
      description           = optional(string)
      source_addresses      = optional(list(string), [])
      source_ip_groups      = optional(list(string), [])
      protocols             = optional(list(object({ type = string, port = number })), [])
      destination_fqdns     = optional(list(string), [])
      destination_fqdn_tags = optional(list(string), [])
      destination_urls      = optional(list(string), [])
      destination_addresses = optional(list(string), [])
      web_categories        = optional(list(string), [])
      terminate_tls         = optional(bool, false)
      http_headers          = optional(map(string), {})
    }))
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Application rule collections, by collection name. Each has:

- `priority` - 100 to 65000, unique within the group.
- `action` - `Allow` or `Deny`.
- `rules` - Application rules, by rule name:
  - `description` - (Optional) Description of the rule.
  - `source_addresses` - (Optional) Source IP addresses, CIDR prefixes or ranges.
  - `source_ip_groups` - (Optional) Source IP group resource IDs.
  - `protocols` - (Optional) Protocols, each `{ type, port }`: `type` is `Http` or `Https`, `port` 0 to 64000.
  - `destination_fqdns` - (Optional) Destination FQDNs; `*` wildcards allowed.
  - `destination_fqdn_tags` - (Optional) FQDN tags, for example `WindowsUpdate`.
  - `destination_urls` - (Optional) Destination URLs (Premium).
  - `destination_addresses` - (Optional) Destination IP addresses or service tags.
  - `web_categories` - (Optional) Web categories.
  - `terminate_tls` - (Optional) Terminate TLS for this rule (Premium). Defaults to `false`.
  - `http_headers` - (Optional) HTTP headers to insert, by header name.
DESCRIPTION

  validation {
    condition     = alltrue([for collection in values(var.application_rule_collections) : contains(["Allow", "Deny"], collection.action) && collection.priority >= 100 && collection.priority <= 65000])
    error_message = "Each application rule collection's `action` must be `Allow` or `Deny`, and its `priority` from 100 to 65000."
  }
  validation {
    condition = alltrue(flatten([for collection in values(var.application_rule_collections) : [
      for rule in values(collection.rules) : [for protocol in rule.protocols : contains(["Http", "Https"], protocol.type) && protocol.port >= 0 && protocol.port <= 64000]
    ]]))
    error_message = "Each application rule protocol's `type` must be `Http` or `Https`, and its `port` from 0 to 64000."
  }
}

variable "network_rule_collections" {
  type = map(object({
    priority = number
    action   = string
    rules = map(object({
      description           = optional(string)
      protocols             = list(string)
      source_addresses      = optional(list(string), [])
      source_ip_groups      = optional(list(string), [])
      destination_addresses = optional(list(string), [])
      destination_ip_groups = optional(list(string), [])
      destination_fqdns     = optional(list(string), [])
      destination_ports     = list(string)
    }))
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Network rule collections, by collection name. Each has:

- `priority` - 100 to 65000, unique within the group.
- `action` - `Allow` or `Deny`.
- `rules` - Network rules, by rule name:
  - `description` - (Optional) Description of the rule.
  - `protocols` - `Any`, `TCP`, `UDP` or `ICMP`.
  - `source_addresses` - (Optional) Source IP addresses, CIDR prefixes or ranges.
  - `source_ip_groups` - (Optional) Source IP group resource IDs.
  - `destination_addresses` - (Optional) Destination IP addresses, CIDR prefixes, ranges or service tags.
  - `destination_ip_groups` - (Optional) Destination IP group resource IDs.
  - `destination_fqdns` - (Optional) Destination FQDNs; needs DNS proxy on the policy.
  - `destination_ports` - Destination ports or ranges, for example `["443", "8000-8080"]`, or `["*"]`.
DESCRIPTION

  validation {
    condition     = alltrue([for collection in values(var.network_rule_collections) : contains(["Allow", "Deny"], collection.action) && collection.priority >= 100 && collection.priority <= 65000])
    error_message = "Each network rule collection's `action` must be `Allow` or `Deny`, and its `priority` from 100 to 65000."
  }
  validation {
    condition = alltrue(flatten([for collection in values(var.network_rule_collections) : [
      for rule in values(collection.rules) : length(rule.protocols) > 0 && alltrue([for protocol in rule.protocols : contains(["Any", "TCP", "UDP", "ICMP"], protocol)])
    ]]))
    error_message = "Each network rule needs `protocols`, each `Any`, `TCP`, `UDP` or `ICMP`."
  }
}

variable "nat_rule_collections" {
  type = map(object({
    priority = number
    rules = map(object({
      description         = optional(string)
      protocols           = list(string)
      source_addresses    = optional(list(string), [])
      source_ip_groups    = optional(list(string), [])
      destination_address = string
      destination_ports   = list(string)
      translated_address  = optional(string)
      translated_fqdn     = optional(string)
      translated_port     = number
    }))
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
DNAT rule collections, by collection name. Each has:

- `priority` - 100 to 65000, unique within the group.
- `rules` - DNAT rules, by rule name:
  - `description` - (Optional) Description of the rule.
  - `protocols` - `TCP` or `UDP`.
  - `source_addresses` - (Optional) Source IP addresses, CIDR prefixes or ranges.
  - `source_ip_groups` - (Optional) Source IP group resource IDs.
  - `destination_address` - The firewall's public IP address the traffic arrives on.
  - `destination_ports` - Destination ports, for example `["443"]`.
  - `translated_address` - (Optional) The private IP address to forward to. Exactly one of `translated_address` and `translated_fqdn`.
  - `translated_fqdn` - (Optional) The FQDN to forward to.
  - `translated_port` - The port to forward to.
DESCRIPTION

  validation {
    condition     = alltrue([for collection in values(var.nat_rule_collections) : collection.priority >= 100 && collection.priority <= 65000])
    error_message = "Each DNAT rule collection's `priority` must be from 100 to 65000."
  }
  validation {
    condition = alltrue(flatten([for collection in values(var.nat_rule_collections) : [
      for rule in values(collection.rules) : length(rule.protocols) > 0 && alltrue([for protocol in rule.protocols : contains(["TCP", "UDP"], protocol)]) && (rule.translated_address == null) != (rule.translated_fqdn == null)
    ]]))
    error_message = "Each DNAT rule needs `protocols` (`TCP` or `UDP`) and exactly one of `translated_address` and `translated_fqdn`."
  }
  validation {
    condition     = length(setintersection(keys(var.nat_rule_collections), concat(keys(var.application_rule_collections), keys(var.network_rule_collections)))) == 0 && length(setintersection(keys(var.application_rule_collections), keys(var.network_rule_collections))) == 0
    error_message = "Rule collection names must be unique across `application_rule_collections`, `network_rule_collections` and `nat_rule_collections`."
  }
}
