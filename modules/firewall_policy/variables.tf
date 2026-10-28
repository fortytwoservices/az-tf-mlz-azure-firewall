variable "location" {
  type        = string
  description = "Azure region of the firewall policy. A child policy must be in its base policy's region; a policy can serve firewalls in any region."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the firewall policy. Changing it replaces the policy."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, underscores, periods and hyphens, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group that holds the firewall policy."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "base_policy_id" {
  type        = string
  default     = null
  description = "(Optional) Resource ID of the parent policy whose rules this policy inherits (except DNAT rules)."

  validation {
    condition     = var.base_policy_id == null || can(provider::azapi::parse_resource_id("Microsoft.Network/firewallPolicies", var.base_policy_id))
    error_message = "`base_policy_id` must be a firewall policy resource ID, or null."
  }
}

variable "dns" {
  type = object({
    proxy_enabled                   = optional(bool, false)
    servers                         = optional(list(string), [])
    require_proxy_for_network_rules = optional(bool)
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
DNS settings of the firewalls that use the policy. Not available on Basic, which sends none:

- `proxy_enabled` - (Optional) Make the firewalls a DNS proxy, which FQDNs in network rules need. Defaults to `false`.
- `servers` - (Optional) Custom DNS servers; Azure DNS when empty.
- `require_proxy_for_network_rules` - (Optional) Whether FQDNs in network rules require the DNS proxy. Azure's default when null.
DESCRIPTION

  validation {
    condition     = var.sku_tier != "Basic" || (!var.dns.proxy_enabled && length(var.dns.servers) == 0 && var.dns.require_proxy_for_network_rules == null)
    error_message = "The Basic tier has no DNS settings (no DNS proxy, no custom DNS servers): leave `dns` empty."
  }
}

variable "explicit_proxy" {
  type = object({
    enabled          = optional(bool, true)
    http_port        = optional(number)
    https_port       = optional(number)
    pac_file_enabled = optional(bool, false)
    pac_file_port    = optional(number)
    pac_file         = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
(Optional) Explicit proxy settings; null leaves explicit proxy off:

- `enabled` - (Optional) Whether explicit proxy mode is on. Defaults to `true`.
- `http_port` and `https_port` - Ports for HTTP and HTTPS, 0 to 64000.
- `pac_file_enabled` - (Optional) Whether the firewall serves a PAC file. Defaults to `false`.
- `pac_file_port` - The port that serves the PAC file, 0 to 64000.
- `pac_file` - SAS URL of the PAC file.
DESCRIPTION

  validation {
    condition = var.explicit_proxy == null ? true : (
      (var.explicit_proxy.enabled ? var.explicit_proxy.http_port != null && var.explicit_proxy.https_port != null : true) &&
      (var.explicit_proxy.pac_file_enabled ? var.explicit_proxy.pac_file_port != null && var.explicit_proxy.pac_file != null : true)
    )
    error_message = "An enabled explicit proxy needs `http_port` and `https_port`, and an enabled PAC file needs `pac_file_port` and `pac_file`."
  }
  validation {
    condition     = var.explicit_proxy == null ? true : alltrue([for port in [var.explicit_proxy.http_port, var.explicit_proxy.https_port, var.explicit_proxy.pac_file_port] : port == null ? true : port >= 0 && port <= 64000])
    error_message = "Explicit proxy ports must be from 0 to 64000."
  }
}

variable "insights" {
  type = object({
    enabled                            = optional(bool, true)
    retention_in_days                  = optional(number)
    default_log_analytics_workspace_id = string
    log_analytics_workspaces           = optional(map(string), {})
  })
  default     = null
  description = <<DESCRIPTION
(Optional) Policy analytics; null leaves them off:

- `enabled` - (Optional) Whether insights are on. Defaults to `true`.
- `retention_in_days` - (Optional) How many days insights are kept.
- `default_log_analytics_workspace_id` - Resource ID of the Log Analytics workspace for firewalls in regions without their own.
- `log_analytics_workspaces` - (Optional) Log Analytics workspace resource IDs by firewall region, for example `{ norwayeast = "/subscriptions/.../workspaces/log-nwe" }`.
DESCRIPTION

  validation {
    condition = var.insights == null ? true : alltrue([
      for id in concat([var.insights.default_log_analytics_workspace_id], values(var.insights.log_analytics_workspaces)) :
      can(provider::azapi::parse_resource_id("Microsoft.OperationalInsights/workspaces", id))
    ])
    error_message = "`insights` workspace IDs must be Log Analytics workspace resource IDs."
  }
}

variable "intrusion_detection" {
  type = object({
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
  })
  default     = null
  description = <<DESCRIPTION
(Optional, Premium) Intrusion detection and prevention (IDPS); null leaves it off:

- `mode` - `Alert`, `Deny` or `Off`. With a base policy, the stricter mode of the two applies. (The schema's IDPS `profile` is not offered: Azure rejects it, `FirewallPolicyIntrusionDetectionProfileNotSupported`, 2026-10-27.)
- `signature_overrides` - (Optional) Signature states by signature ID: `Alert`, `Deny` or `Off`.
- `traffic_bypass` - (Optional) Traffic that bypasses IDPS, by rule name: `protocol` (`ANY`, `ICMP`, `TCP` or `UDP`), `description`, and source and destination addresses, IP group IDs and ports.
- `private_ranges` - (Optional) The ranges IDPS treats as private; the IANA RFC 1918 ranges when empty.
DESCRIPTION

  validation {
    condition     = var.intrusion_detection == null || var.sku_tier == "Premium"
    error_message = "Intrusion detection needs the Premium tier."
  }
  validation {
    condition = var.intrusion_detection == null ? true : (
      contains(["Alert", "Deny", "Off"], var.intrusion_detection.mode) &&
      alltrue([for mode in values(var.intrusion_detection.signature_overrides) : contains(["Alert", "Deny", "Off"], mode)]) &&
      alltrue([for bypass in values(var.intrusion_detection.traffic_bypass) : contains(["ANY", "ICMP", "TCP", "UDP"], bypass.protocol)])
    )
    error_message = "Intrusion detection `mode` and signature states must be `Alert`, `Deny` or `Off`, and bypass `protocol` `ANY`, `ICMP`, `TCP` or `UDP`."
  }
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "lock_dependencies" {
  type        = map(string)
  default     = {}
  nullable    = false
  description = "The policy's rule collection groups, created by the caller, as their `lock_dependency` outputs by any stable key. Azure applies the policy's lock to them too, so a change to this map removes the lock around it."
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Controls the Managed Identity configuration on this resource. TLS inspection reads its certificate from Key Vault with a user-assigned identity. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
DESCRIPTION

  validation {
    condition = alltrue([
      for id in var.managed_identities.user_assigned_resource_ids :
      can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", id))
    ])
    error_message = "Each entry in `managed_identities.user_assigned_resource_ids` must be a valid user-assigned managed identity resource ID."
  }
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
A map of role assignments to create on the firewall policy. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. If not set, a random UUID will be generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "sku_tier" {
  type        = string
  default     = "Standard"
  description = "Tier of the policy: `Basic`, `Standard` or `Premium`. It matches the tier of the firewalls that use it."
  nullable    = false

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_tier)
    error_message = "`sku_tier` must be `Basic`, `Standard` or `Premium`."
  }
}

variable "snat" {
  type = object({
    private_ranges                    = optional(list(string))
    auto_learn_private_ranges_enabled = optional(bool, false)
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Which destinations the firewalls do not SNAT:

- `private_ranges` - (Optional) Private ranges not to SNAT, as CIDR prefixes, for example `["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "198.18.0.0/15"]`. Azure's default, the IANA private ranges, when null. The `IANAPrivateRanges` keyword is not accepted: Azure stores it as the four ranges it stands for, so every later plan would differ.
- `auto_learn_private_ranges_enabled` - (Optional) Whether the firewalls learn further private ranges themselves. Defaults to `false`.
DESCRIPTION

  validation {
    condition     = !contains(coalesce(var.snat.private_ranges, []), "IANAPrivateRanges")
    error_message = "List the IANA private ranges themselves (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10) instead of `IANAPrivateRanges`, or leave `snat.private_ranges` null for Azure's default: Azure stores the keyword as the ranges, so every later plan would differ."
  }
}

variable "sql_redirect_allowed" {
  type        = bool
  default     = false
  description = "Whether SQL redirect traffic filtering is on. It requires that no rule uses ports 11000 to 11999."
  nullable    = false
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "threat_intelligence_allowlist" {
  type = object({
    ip_addresses = optional(list(string), [])
    fqdns        = optional(list(string), [])
  })
  default     = {}
  nullable    = false
  description = "IP addresses and FQDNs that threat intelligence does not filter."
}

variable "threat_intelligence_mode" {
  type        = string
  default     = "Alert"
  description = "Threat intelligence mode: `Alert`, `Deny` or `Off`. The Basic tier alerts only."
  nullable    = false

  validation {
    condition     = contains(["Alert", "Deny", "Off"], var.threat_intelligence_mode)
    error_message = "`threat_intelligence_mode` must be `Alert`, `Deny` or `Off`."
  }
}

variable "tls_certificate" {
  type = object({
    key_vault_secret_id = string
    name                = string
  })
  default     = null
  description = <<DESCRIPTION
(Optional, Premium) The intermediate CA certificate for TLS inspection; null leaves it off. The user-assigned identity in `managed_identities` needs Get and List on the vault's secrets.

- `key_vault_secret_id` - Secret ID of the certificate (a base-64 encoded PFX without password) in Key Vault.
- `name` - Name of the certificate.
DESCRIPTION

  validation {
    condition     = var.tls_certificate == null || var.sku_tier == "Premium"
    error_message = "TLS inspection needs the Premium tier."
  }
}
