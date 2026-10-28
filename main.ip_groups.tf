module "ip_group" {
  source   = "./modules/ip_group"
  for_each = var.ip_groups

  name                = each.value.name
  parent_id           = var.parent_id
  location            = coalesce(each.value.location, var.location)
  ip_addresses        = each.value.ip_addresses
  tags                = var.tags
  resource_types      = var.resource_types.network_ip_groups
  ignore_body_changes = var.ignore_body_changes.network_ip_groups
  retry               = var.retry
  timeouts            = var.timeouts
}
