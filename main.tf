resource "azapi_resource" "this" {
  type      = var.resource_types.network_azure_firewalls
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  body = merge(
    {
      # The classic rule collections (applicationRuleCollections and the like) are left out: rules live
      # in the policy.
      properties = {
        sku            = { name = "AZFW_VNet", tier = var.sku_tier }
        firewallPolicy = { id = local.firewall_policy_id }
        # The first IP configuration holds the subnet; further public IP addresses get their own,
        # without a subnet.
        ipConfigurations = concat(
          [{
            name = var.virtual_network.ip_configuration_name
            properties = {
              subnet          = { id = var.virtual_network.subnet_id }
              publicIPAddress = var.virtual_network.public_ip == null && var.virtual_network.public_ip_resource_id == null ? null : { id = local.public_ip_ids[var.virtual_network.ip_configuration_name] }
            }
          }],
          [for name in sort(concat(keys(var.virtual_network.additional_public_ips), keys(var.virtual_network.additional_public_ip_resource_ids))) : {
            name       = name
            properties = { publicIPAddress = { id = local.public_ip_ids[name] } }
          }],
        )
        managementIpConfiguration = var.virtual_network.management == null ? null : {
          name = var.virtual_network.management.ip_configuration_name
          properties = {
            subnet          = { id = var.virtual_network.management.subnet_id }
            publicIPAddress = { id = local.public_ip_ids[var.virtual_network.management.ip_configuration_name] }
          }
        }
        autoscaleConfiguration = var.autoscale == null ? null : {
          minCapacity = var.autoscale.min_capacity
          maxCapacity = var.autoscale.max_capacity
        }
      }
    },
    # Left out when null, so Azure's choice is not compared; sorted, so their order changes nothing.
    local.zones == null ? {} : { zones = local.zones },
  )
  ignore_body_changes = length(var.ignore_body_changes.network_azure_firewalls) > 0 ? var.ignore_body_changes.network_azure_firewalls : null
  # Changes Azure makes only by stopping and starting the firewall, which the module does not do: its
  # zones; the management NIC (Learn, "Azure Firewall Management NIC"); its virtual network (allocation
  # binds the subnet); and a tier change to or from Basic (Learn, "Change Azure Firewall SKU": Basic
  # supports no SKU change on an existing firewall). Compared as inputs, so going back to null also
  # replaces it.
  replace_triggers_external_values = {
    basic      = var.sku_tier == "Basic"
    management = var.virtual_network.management != null
    subnet_id  = lower(var.virtual_network.subnet_id)
    zones      = local.zones
  }
  replace_triggers_refs  = ["properties.sku.name"]
  response_export_values = ["properties.ipConfigurations"]
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  # The firewall is updated with the policy; writing the rules first keeps the two from overlapping.
  depends_on = [module.rule_collection_group]
}
