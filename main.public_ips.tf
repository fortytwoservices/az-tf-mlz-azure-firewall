module "public_ip" {
  source   = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=v0.1.2"
  for_each = local.created_public_ips

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
