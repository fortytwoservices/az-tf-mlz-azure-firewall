variable "location" {
  type        = string
  description = "Azure region of the firewall, and of the policy, public IP addresses and IP groups the module creates."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the firewall. Changing it replaces the firewall."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,54}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 56 characters: letters, digits, underscores, periods and hyphens, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group that holds the firewall and what the module creates for it."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "virtual_network" {
  type = object({
    subnet_id             = string
    ip_configuration_name = optional(string, "ipconfig")
    public_ip = optional(object({
      name                = string
      public_ip_prefix_id = optional(string)
    }))
    public_ip_resource_id = optional(string)
    additional_public_ips = optional(map(object({
      name                = string
      public_ip_prefix_id = optional(string)
    })), {})
    additional_public_ip_resource_ids = optional(map(string), {})
    management = optional(object({
      subnet_id             = string
      ip_configuration_name = optional(string, "management")
      public_ip = optional(object({
        name                = string
        public_ip_prefix_id = optional(string)
      }))
      public_ip_resource_id = optional(string)
    }))
  })
  nullable    = false
  description = <<DESCRIPTION
The firewall in a virtual network hub (`AZFW_VNet`). The subnets belong to the caller (the hub composition creates them). Each public IP address is either created by this module through `az-tf-mlz-public-ip` (a `public_ip` object: `name`, and optionally `public_ip_prefix_id` to take it from a prefix) or an existing one (a `public_ip_resource_id`). Which addresses are created depends only on which objects are set, so names and IDs may be unknown until apply.

- `subnet_id` - Resource ID of the `AzureFirewallSubnet` (/26 or larger).
- `ip_configuration_name` - (Optional) Name of the first IP configuration, which holds the subnet. Defaults to `ipconfig`.
- `public_ip` or `public_ip_resource_id` - (Optional) The first IP configuration's public IP address, created or existing. Neither only with `management` (forced tunnelling without a data-path public IP).
- `additional_public_ips` and `additional_public_ip_resource_ids` - (Optional) Further public IP addresses, created or existing, each its own IP configuration named by its key.
- `management` - (Optional) The management IP configuration, required for Basic and for forced tunnelling: `subnet_id` of the `AzureFirewallManagementSubnet` (/26 or larger), `ip_configuration_name` (defaults to `management`), and exactly one of `public_ip` and `public_ip_resource_id`. Adding or removing it replaces the firewall: Azure enables the management NIC on an existing firewall only by stopping and starting it.
DESCRIPTION

  validation {
    condition     = var.virtual_network.public_ip == null || var.virtual_network.public_ip_resource_id == null
    error_message = "Set at most one of `virtual_network.public_ip` (created) and `virtual_network.public_ip_resource_id` (existing)."
  }
  validation {
    condition     = var.virtual_network.public_ip != null || var.virtual_network.public_ip_resource_id != null || var.virtual_network.management != null
    error_message = "The first IP configuration needs a public IP address unless `management` is set (forced tunnelling)."
  }
  validation {
    condition     = var.virtual_network.management == null ? true : (var.virtual_network.management.public_ip == null) != (var.virtual_network.management.public_ip_resource_id == null)
    error_message = "`virtual_network.management` needs exactly one of `public_ip` (created) and `public_ip_resource_id` (existing)."
  }
  validation {
    condition = alltrue([
      for id in concat(
        [var.virtual_network.public_ip_resource_id],
        values(var.virtual_network.additional_public_ip_resource_ids),
        [var.virtual_network.management == null ? null : var.virtual_network.management.public_ip_resource_id],
      ) : id == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPAddresses", id))
    ])
    error_message = "Each public IP resource ID must be a public IP address resource ID."
  }
  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", var.virtual_network.subnet_id)) && endswith(lower(var.virtual_network.subnet_id), "/subnets/azurefirewallsubnet")
    error_message = "`virtual_network.subnet_id` must be the resource ID of a subnet named `AzureFirewallSubnet`."
  }
  validation {
    condition     = var.virtual_network.management == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", var.virtual_network.management.subnet_id)) && endswith(lower(var.virtual_network.management.subnet_id), "/subnets/azurefirewallmanagementsubnet")
    error_message = "`virtual_network.management.subnet_id` must be the resource ID of a subnet named `AzureFirewallManagementSubnet`."
  }
  validation {
    condition = length(distinct(concat(
      [var.virtual_network.ip_configuration_name],
      keys(var.virtual_network.additional_public_ips),
      keys(var.virtual_network.additional_public_ip_resource_ids),
      var.virtual_network.management == null ? [] : [var.virtual_network.management.ip_configuration_name],
    ))) == 1 + length(var.virtual_network.additional_public_ips) + length(var.virtual_network.additional_public_ip_resource_ids) + (var.virtual_network.management == null ? 0 : 1)
    error_message = "IP configuration names (`ip_configuration_name`, the keys of `additional_public_ips` and `additional_public_ip_resource_ids`, and `management.ip_configuration_name`) must be unique."
  }
  validation {
    condition     = var.sku_tier != "Basic" || var.virtual_network.management != null
    error_message = "A Basic firewall needs `virtual_network.management`."
  }
}

variable "autoscale" {
  type = object({
    min_capacity = optional(number)
    max_capacity = optional(number)
  })
  default     = null
  description = "(Optional) Capacity units the firewall scales between, each 2 or more; Azure's defaults when null."

  validation {
    condition     = var.autoscale == null ? true : alltrue([for capacity in [var.autoscale.min_capacity, var.autoscale.max_capacity] : capacity == null ? true : capacity >= 2])
    error_message = "`autoscale` capacities must be 2 or more."
  }
}

variable "firewall_policy" {
  type = object({
    name                          = string
    base_policy_id                = optional(string)
    threat_intelligence_mode      = optional(string, "Alert")
    threat_intelligence_allowlist = optional(object({ ip_addresses = optional(list(string), []), fqdns = optional(list(string), []) }), {})
    dns = optional(object({
      proxy_enabled                   = optional(bool, false)
      servers                         = optional(list(string), [])
      require_proxy_for_network_rules = optional(bool)
    }), {})
    snat = optional(object({
      private_ranges                    = optional(list(string))
      auto_learn_private_ranges_enabled = optional(bool, false)
    }), {})
    sql_redirect_allowed = optional(bool, false)
    explicit_proxy = optional(object({
      enabled          = optional(bool, true)
      http_port        = optional(number)
      https_port       = optional(number)
      pac_file_enabled = optional(bool, false)
      pac_file_port    = optional(number)
      pac_file         = optional(string)
    }))
    insights = optional(object({
      enabled                            = optional(bool, true)
      retention_in_days                  = optional(number)
      default_log_analytics_workspace_id = string
      log_analytics_workspaces           = optional(map(string), {})
    }))
    intrusion_detection = optional(object({
      mode                = string
      signature_overrides = optional(map(string), {})
      traffic_bypass = optional(map(object({
        description           = optional(string)
        protocol              = string
        source_addresses      = optional(list(string), [])
        source_ip_groups      = optional(list(string), [])
        destination_addresses = optional(list(string), [])
        destination_ip_groups = optional(list(string), [])
        destination_ports     = optional(list(string), [])
      })), {})
      private_ranges = optional(list(string), [])
    }))
    tls_certificate = optional(object({
      key_vault_secret_id = string
      name                = string
    }))
    managed_identities = optional(object({
      system_assigned            = optional(bool, false)
      user_assigned_resource_ids = optional(set(string), [])
    }), {})
    lock = optional(object({
      kind  = string
      name  = optional(string, null)
      notes = optional(string, null)
    }))
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
  })
  default     = null
  description = <<DESCRIPTION
(Optional) The firewall policy the module creates, with the firewall's tier, region and tags; exactly one of `firewall_policy` and `firewall_policy_id`. The settings are those of `modules/firewall_policy`, whose README describes each: `name` (required), `base_policy_id`, `threat_intelligence_mode`, `threat_intelligence_allowlist`, `dns`, `snat`, `sql_redirect_allowed`, `explicit_proxy`, `insights`, `intrusion_detection` (Premium), `tls_certificate` (Premium), `managed_identities`, `lock` and `role_assignments`. IP group keys from `ip_groups` work in `intrusion_detection.traffic_bypass` as in rules.
DESCRIPTION
}

variable "firewall_policy_id" {
  type        = string
  default     = null
  description = "(Optional) Resource ID of an existing firewall policy for the firewall; exactly one of `firewall_policy` and `firewall_policy_id`. The module's `rule_collection_groups` are created on it."

  validation {
    condition     = (var.firewall_policy_id == null) != (var.firewall_policy == null)
    error_message = "Set exactly one of `firewall_policy` (created by the module) and `firewall_policy_id` (existing)."
  }
  validation {
    condition     = var.firewall_policy_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/firewallPolicies", var.firewall_policy_id))
    error_message = "`firewall_policy_id` must be a firewall policy resource ID, or null."
  }
}

variable "ip_groups" {
  type = map(object({
    name         = string
    ip_addresses = list(string)
    location     = optional(string)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
IP groups the module creates in `parent_id`, by key. Rules and IDPS bypass entries take these keys wherever they take IP group IDs (`source_ip_groups`, `destination_ip_groups`); anything that is not a key is passed on as an ID.

- `name` - Name of the IP group.
- `ip_addresses` - IP addresses, CIDR prefixes and ranges.
- `location` - (Optional) Region of the IP group; the firewall's when null.
DESCRIPTION
}

variable "rule_collection_groups" {
  type = map(object({
    priority = number
    application_rule_collections = optional(map(object({
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
    })), {})
    network_rule_collections = optional(map(object({
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
    })), {})
    nat_rule_collections = optional(map(object({
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
    })), {})
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Rule collection groups on the policy, by group name: `priority` (100 to 65000) and `application_rule_collections`, `network_rule_collections` and `nat_rule_collections`, as described in `modules/rule_collection_group`. Keys of `ip_groups` work wherever an IP group ID is taken.
DESCRIPTION
}

variable "sku_tier" {
  type        = string
  default     = "Standard"
  description = "Tier of the firewall and of the policy the module creates: `Basic`, `Standard` or `Premium`."
  nullable    = false

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_tier)
    error_message = "`sku_tier` must be `Basic`, `Standard` or `Premium`."
  }
}

variable "zones" {
  type        = list(string)
  default     = null
  description = "(Optional) Availability zones of the firewall and of the public IP addresses the module creates, for example `[\"1\", \"2\", \"3\"]`. Null leaves them out, which Microsoft advises for new firewalls: Azure spreads them across zones itself where the region supports it (Azure Firewall FAQ), and the public IP addresses are zone-redundant where the region has zones. Changing them replaces the firewall."

  validation {
    condition     = var.zones == null ? true : length(var.zones) > 0 && alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "`zones` must be null or a non-empty list of `1`, `2` and `3`."
  }
}
