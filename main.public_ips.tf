module "public_ip" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=v0.1.1"
  for_each = { for name, public_ip in local.public_ips : name => public_ip if public_ip.name != null }

  name                = each.value.name
  parent_id           = var.parent_id
  location            = var.location
  zones               = local.zones
  public_ip_prefix_id = each.value.public_ip_prefix_id
  tags                = var.tags
  resource_types      = var.resource_types.network_public_ip_addresses
  ignore_body_changes = var.ignore_body_changes.network_public_ip_addresses
  retry               = var.retry
  timeouts            = var.timeouts
}
