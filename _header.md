# az-tf-mlz-azure-firewall

A Fortytwo managed landing zone (MLZ) module for Azure Firewall, in AzAPI: the firewall
(`Microsoft.Network/azureFirewalls`), its public IP addresses, its policy, the policy's rule collection
groups and the IP groups the rules use. Each type besides the firewall is a submodule that can also be
called on its own, so a separate rules state can manage `modules/rule_collection_group` and
`modules/ip_group` without planning the firewall.

- **A firewall in a virtual network hub** (`virtual_network`, `AZFW_VNet`), Basic, Standard or Premium. The first IP
  configuration holds the `AzureFirewallSubnet` and a public IP address; further public IP addresses get
  their own configurations. A management IP configuration in `AzureFirewallManagementSubnet` is required
  for Basic and for forced tunnelling. Public IP addresses are created through
  [`az-tf-mlz-public-ip`](https://github.com/fortytwoservices/az-tf-mlz-public-ip), or given by ID.
  Zones are left to Azure unless set; changing them replaces the firewall. The private IP address, the
  next hop for routes to the firewall, is an output.
- **Policy rules only.** The firewall uses a policy the module creates with the firewall's tier
  (`firewall_policy`, `modules/firewall_policy`) or an existing one (`firewall_policy_id`). The classic
  rule collections on the firewall itself are not supported.
- **Rules are maps keyed by name** (groups, collections, rules), so adding one never shifts the others.
  Keys of `ip_groups` work wherever an IP group ID is taken. Rule collection groups are written one at a
  time per policy, before the firewall, and the default `retry` covers `AnotherOperationInProgress`.
- **Removing a setting reaches Azure.** Every policy setting and rule field is sent, empty when unset,
  because azapi compares only the keys in the body.
- Lock, role assignments and diagnostic settings on the firewall, and lock and role assignments on the
  policy, as in Azure Verified Modules, through
  [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces). The policy's lock
  also covers its rule collection groups, which pass their `lock_dependency` to it.
- **Or a firewall in a Virtual WAN hub** (`virtual_hub`, `AZFW_Hub`, a secured hub): Azure assigns its public
  IP addresses (`public_ip_count`), and `modules/routing_intent` sends the hub's Internet and/or private
  traffic through it. The hub belongs to the caller; moving the firewall to another hub replaces it.

```hcl
module "azure_firewall" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-azure-firewall.git?ref=vX.Y.Z"

  name      = "afw-hub-nwe"
  parent_id = "/subscriptions/<subscription>/resourceGroups/<resource group>"
  location  = "norwayeast"
  virtual_network = {
    subnet_id = "<AzureFirewallSubnet ID>"
    public_ip = { name = "pip-afw-hub-nwe" }
  }
  firewall_policy = { name = "afwp-hub-nwe", dns = { proxy_enabled = true } }
  rule_collection_groups = {
    platform = {
      priority = 200
      network_rule_collections = {
        dns = {
          priority = 300
          action   = "Allow"
          rules = {
            spokes = { protocols = ["UDP"], source_addresses = ["10.1.0.0/16"], destination_addresses = ["10.0.0.4"], destination_ports = ["53"] }
          }
        }
      }
    }
  }
}
```

The examples deploy a Standard firewall in a VNet hub with a policy, an IP group and rules (`default`), and
one in a Virtual WAN hub with routing intent (`virtual_hub`).
